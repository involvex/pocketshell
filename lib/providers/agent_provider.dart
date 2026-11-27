import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:opencode_api/opencode_api.dart' hide ConfigService;
import 'package:uuid/uuid.dart';

import '../models/agent_connection.dart';
import '../models/agent_permission_request.dart';
import '../models/agent_prompt_attachment.dart';
import '../models/ssh_profile.dart';
import '../providers/ssh_provider.dart';
import '../services/config_repository.dart';
import '../services/opencode_connection_service.dart';
import '../services/opencode_v2_mappers.dart';
import '../services/ssh_local_forward.dart';
import '../utils/agent_event_policy.dart';
import '../utils/agent_prompt_utils.dart';
import '../utils/agent_session_utils.dart';

class AgentProvider extends ChangeNotifier {
  AgentProvider({ConfigRepository? config})
      : _config = config ?? ConfigServiceRepository();

  final ConfigRepository _config;
  SSHProvider? _ssh;

  /// Wired from [ChangeNotifierProxyProvider] so agent tunnels can reuse SSH.
  set ssh(SSHProvider value) => _ssh = value;

  final List<AgentConnection> _connections = [];
  String? _activeConnectionId;
  AgentPermissionRequest? _pendingPermission;

  List<AgentConnection> get connections =>
      List<AgentConnection>.unmodifiable(_connections);
  String? get activeConnectionId => _activeConnectionId;
  AgentConnection? get activeConnection {
    if (_activeConnectionId == null) return null;
    try {
      return _connections.firstWhere((c) => c.id == _activeConnectionId);
    } catch (_) {
      return null;
    }
  }

  AgentPermissionRequest? get pendingPermission => _pendingPermission;

  void Function(String message)? onLog;

  final Map<String, Timer> _reloadDebounce = <String, Timer>{};
  final Set<String> _reloadInFlight = <String>{};
  final Set<String> _reloadQueued = <String>{};

  Future<void> connectFromProfileAndOpenRecent(SSHProfile profile) async {
    final connection = await connectFromProfile(profile);
    final recent = connection.sessions.where((s) => s.id != null).firstOrNull;
    if (recent?.id != null) {
      await selectSession(connection.id, recent!.id!);
    }
  }

  Future<AgentConnection> connectFromProfile(SSHProfile profile) async {
    if (profile.agentAuthUsesCleartextNetwork &&
        profile.agentAuthFallsBackToSshPassword) {
      throw StateError(
        'Set an Agent password, enable HTTPS, or tunnel over SSH. '
        'The SSH password is not sent over cleartext HTTP.',
      );
    }
    if (profile.agentAuthUsesCleartextNetwork) {
      onLog?.call(
        'Warning: OpenCode HTTP to ${profile.host}:${profile.agentPort} '
        'sends credentials in cleartext. Prefer HTTPS or an SSH tunnel.',
      );
    }

    SshLocalForward? tunnel;
    var baseUrl = profile.agentBaseUrl;

    if (profile.tunnelAgent) {
      final prepared = await _prepareAgentTunnel(profile);
      tunnel = prepared.tunnel;
      baseUrl = prepared.baseUrl;
    }

    final service = OpenCodeConnectionService(
      baseUrl: baseUrl,
      username: profile.effectiveAgentUsername,
      password: profile.effectiveAgentPassword,
      allowInsecureTls: profile.useHttps && profile.allowSelfSignedCerts,
    );

    try {
      await service.connect();
      final savedDirectory = await _config.getAgentLastDirectory();
      final directory = (savedDirectory != null && savedDirectory.isNotEmpty)
          ? savedDirectory
          : null;
      final sessions = sortSessionsByUpdatedDesc(
        await service.getSessions(directory: directory),
      );
      final connection = AgentConnection(
        id: const Uuid().v4(),
        profile: profile,
        service: service,
        sessions: sessions,
        isConnected: true,
        selectedDirectory: directory,
        agentTunnel: tunnel,
      );

      _wireConnection(connection);

      _connections.add(connection);
      _activeConnectionId = connection.id;
      onLog?.call(
        'Agent connected: ${profile.name} ($baseUrl)',
      );
      notifyListeners();
      // ignore: unawaited_futures
      _loadMetadata(connection);
      return connection;
    } catch (e) {
      service.dispose();
      if (tunnel != null && !tunnel.isClosed) {
        await tunnel.close();
      }
      rethrow;
    }
  }

  /// Ensures an SSH session exists and opens a loopback forward to the agent.
  Future<({SshLocalForward tunnel, String baseUrl})> _prepareAgentTunnel(
    SSHProfile profile,
  ) async {
    final ssh = _ssh;
    if (ssh == null) {
      throw StateError(
        'SSH provider unavailable. Cannot tunnel agent without SSH.',
      );
    }

    var session = ssh.findConnectedSessionForProfile(profile);
    if (session == null) {
      onLog?.call(
        'Agent tunnel: connecting SSH session for ${profile.name}...',
      );
      session = ssh.createSessionFromProfile(profile, name: profile.name);
      await ssh.connectSession(session.id);
      session = ssh.findConnectedSessionForProfile(profile);
    }

    final client = session?.client;
    if (session == null || client == null || !session.isConnected) {
      throw StateError(
        'No SSH session for ${profile.host}. Connect Client first, '
        'or check credentials, then retry Agents with "Tunnel agent" enabled.',
      );
    }

    final tunnel = await SshLocalForward.start(
      client: client,
      remoteHost: '127.0.0.1',
      remotePort: profile.agentPort,
    );
    final scheme = profile.useHttps ? 'https' : 'http';
    final baseUrl = '$scheme://127.0.0.1:${tunnel.localPort}';
    onLog?.call(
      'Agent tunnel ready: $baseUrl -> '
      '${profile.host} 127.0.0.1:${profile.agentPort}',
    );
    return (tunnel: tunnel, baseUrl: baseUrl);
  }

  Future<AgentConnection> connectFromUrl({
    required String url,
    String username = 'opencode',
    String password = '',
    String name = 'Manual',
  }) async {
    final profile = SSHProfile(
      name: name,
      host: Uri.parse(url).host,
      username: 'unused',
      agentUsername: username,
      agentPassword: password,
      agentPort: Uri.parse(url).port == 0 ? 5000 : Uri.parse(url).port,
      useHttps: url.startsWith('https'),
    );
    return connectFromProfile(profile);
  }

  Future<AgentConnection> connectToLocalDesktop({
    required int port,
    String username = 'opencode',
    String password = '',
  }) async {
    final profile = SSHProfile(
      name: 'Local Desktop',
      host: '127.0.0.1',
      username: 'unused',
      agentUsername: username,
      agentPassword: password,
      agentPort: port,
    );

    final service = OpenCodeConnectionService(
      baseUrl: profile.agentBaseUrl,
      username: profile.effectiveAgentUsername,
      password: profile.effectiveAgentPassword,
      allowInsecureTls: profile.useHttps && profile.allowSelfSignedCerts,
    );

    try {
      await service.connect();

      String? directory = await _config.getAgentLastDirectory();
      if (directory == null || directory.isEmpty) {
        directory = await service.getServerPath();
      }

      final sessions = sortSessionsByUpdatedDesc(
        await service.getSessions(
          directory: directory,
        ),
      );

      final connection = AgentConnection(
        id: const Uuid().v4(),
        profile: profile,
        service: service,
        sessions: sessions,
        isConnected: true,
        isLocal: true,
        selectedDirectory: directory,
      );

      _wireConnection(connection);

      _connections.add(connection);
      _activeConnectionId = connection.id;
      onLog?.call(
        'Agent connected locally (${profile.agentBaseUrl})',
      );
      notifyListeners();
      // ignore: unawaited_futures
      _loadMetadata(connection);
      return connection;
    } catch (e) {
      service.dispose();
      rethrow;
    }
  }

  Future<void> setDirectory(String connectionId, String path) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    connection.selectedDirectory = path;
    await _config.saveAgentLastDirectory(path);
    await refreshSessions(connectionId);
    onLog?.call('Agent directory set: $path');
  }

  Future<void> disconnect(String connectionId) async {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index == -1) return;

    final connection = _connections[index];
    connection.disposeSubscriptions();
    connection.service.dispose();
    _connections.removeAt(index);

    if (_activeConnectionId == connectionId) {
      _activeConnectionId =
          _connections.isNotEmpty ? _connections.last.id : null;
    }

    onLog?.call('Agent disconnected: ${connection.profile.name}');
    notifyListeners();
  }

  void switchActiveConnection(String connectionId) {
    if (_connections.any((c) => c.id == connectionId)) {
      _activeConnectionId = connectionId;
      notifyListeners();
    }
  }

  Future<void> refreshSessions(String connectionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    final directory = agentDirectoryScopeForConnection(connection);
    connection.sessions = sortSessionsByUpdatedDesc(
      await connection.service.getSessions(directory: directory),
    );
    notifyListeners();
  }

  Future<void> selectSession(String connectionId, String sessionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    connection.activeSessionId = sessionId;
    connection.resetSessionUsage();
    connection.isLoadingMessages = true;
    notifyListeners();

    try {
      final raw = await connection.service.getRawMessages(sessionId);
      connection.messages = raw.map(mapV2Message).toList();
      _applyMessageListUsage(connection, raw);
    } finally {
      connection.isLoadingMessages = false;
      notifyListeners();
    }
    // ignore: unawaited_futures
    _loadMetadata(connection);
  }

  void clearActiveSession(String connectionId) {
    final connection = _findConnection(connectionId);
    if (connection == null) return;
    connection.activeSessionId = null;
    connection.messages = [];
    notifyListeners();
  }

  void toggleCollapseToolParts(String connectionId) {
    final connection = _findConnection(connectionId);
    if (connection == null) return;
    connection.collapseToolParts = !connection.collapseToolParts;
    notifyListeners();
  }

  Future<void> createSession(String connectionId, {String? title}) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    final directory = agentDirectoryScopeForConnection(connection);
    final session = await connection.service.createSession(
      title: title,
      directory: directory,
    );

    final refreshedDirectory = agentDirectoryScopeForConnection(connection);
    connection.sessions = sortSessionsByUpdatedDesc(
      await connection.service.getSessions(directory: refreshedDirectory),
    );
    if (session.id != null) {
      await selectSession(connectionId, session.id!);
    }
    onLog?.call('Agent session created: ${session.title ?? session.id}');
    notifyListeners();
  }

  Future<void> deleteSession(String connectionId, String sessionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    await connection.service.deleteSession(sessionId);

    final directory = agentDirectoryScopeForConnection(connection);
    connection.sessions = sortSessionsByUpdatedDesc(
      await connection.service.getSessions(directory: directory),
    );
    if (connection.activeSessionId == sessionId) {
      connection.activeSessionId = null;
      connection.messages = [];
    }
    notifyListeners();
  }

  Future<void> sendPrompt(
    String connectionId,
    String text, {
    List<AgentPromptAttachment> attachments = const <AgentPromptAttachment>[],
  }) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;

    connection.isSending = true;
    notifyListeners();

    try {
      final sessionId = connection.activeSessionId!;
      if (isSlashCommand(trimmed)) {
        await connection.service.executeCommand(sessionId, trimmed);
        onLog?.call('Agent command sent: $trimmed');
      } else {
        final files = attachments
            .map((AgentPromptAttachment a) => a.apiPayload)
            .toList(growable: false);
        await connection.service.sendMessageAsync(
          sessionId,
          trimmed,
          files: files.isEmpty ? null : files,
        );
        onLog?.call('Agent prompt sent to ${connection.profile.name}');
      }
    } finally {
      connection.isSending = false;
      notifyListeners();
    }
  }

  Future<void> revertMessagePart(
    String connectionId,
    String messageId, {
    String? partId,
  }) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;
    if (messageId.isEmpty) return;

    connection.isSending = true;
    notifyListeners();

    try {
      final sessionId = connection.activeSessionId!;
      await connection.service.revertStage(sessionId, messageId);
      await connection.service.revertCommit(sessionId);
      if (partId != null && partId.isNotEmpty) {
        onLog?.call('Agent revert committed for $messageId ($partId)');
      } else {
        onLog?.call('Agent revert committed for $messageId');
      }
      await _reloadMessages(connectionId);
    } catch (e) {
      onLog?.call('Agent revert failed: $e');
      rethrow;
    } finally {
      connection.isSending = false;
      notifyListeners();
    }
  }

  Future<void> refreshProviders(String connectionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    try {
      connection.providerInfo = await connection.service.getProviders();
      connection.configProviders =
          await connection.service.getConfigProviders();
      connection.modelOptions = deriveModelOptions(
        providerInfo: connection.providerInfo,
        configProviders: connection.configProviders,
      );
      onLog?.call('Agent providers refreshed');
    } catch (e) {
      onLog?.call('Agent provider refresh failed: $e');
    }
    notifyListeners();
  }

  Future<void> setModel(String connectionId, String modelId) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;

    final trimmed = modelId.trim();
    if (trimmed.isEmpty) return;

    connection.isSending = true;
    notifyListeners();

    try {
      await connection.service.executeCommand(
        connection.activeSessionId!,
        '/model $trimmed',
      );
      connection.selectedModelId = trimmed;
      onLog?.call('Agent model set: $trimmed');
    } finally {
      connection.isSending = false;
      notifyListeners();
    }
  }

  Future<void> connectProvider(
    String connectionId,
    String providerId,
    String apiKey,
  ) async {
    final connection = _findConnection(connectionId);
    if (connection == null) return;

    final trimmedKey = apiKey.trim();
    if (providerId.isEmpty || trimmedKey.isEmpty) return;

    await connection.service.setProviderAuth(
      providerId,
      <String, dynamic>{
        'type': 'api',
        'key': trimmedKey,
      },
    );
    await refreshProviders(connectionId);
    onLog?.call('Agent provider connected: $providerId');
  }

  Future<void> openModelsPicker(String connectionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;

    await connection.service.executeCommand(
      connection.activeSessionId!,
      '/models',
    );
    onLog?.call('Agent models picker opened');
  }

  String? currentModelId(AgentConnection connection) {
    return resolveCurrentModelId(
      selectedModelId: connection.selectedModelId,
      providerInfo: connection.providerInfo,
      configProviders: connection.configProviders,
    );
  }

  Future<void> respondToPermission({
    required String response,
    bool remember = false,
  }) async {
    final pending = _pendingPermission;
    if (pending == null) return;

    await pending.service.respondToPermission(
      pending.sessionId,
      pending.permissionId,
      response: response,
      remember: remember,
    );
    _pendingPermission = null;
    onLog?.call('Agent permission response: $response');
    notifyListeners();
  }

  void dismissPermission() {
    _pendingPermission = null;
    notifyListeners();
  }

  AgentConnection? _findConnection(String connectionId) {
    try {
      return _connections.firstWhere((c) => c.id == connectionId);
    } catch (_) {
      return null;
    }
  }

  void _wireConnection(AgentConnection connection) {
    connection.eventSub = connection.service.events.listen(
      (event) => _handleEvent(connection.id, event),
    );
    connection.connectionEventSub =
        connection.service.connectionEvents.listen((event) {
      if (event.type == ConnectionEventType.disconnected) {
        connection.isConnected = false;
        onLog?.call(
          'Agent event stream ended: ${connection.profile.name}',
        );
        notifyListeners();
      }
    });
  }

  Future<void> reconnectDisconnectedAgents() async {
    for (final connection in _connections) {
      if (connection.isConnected) {
        await connection.service.reconnectEventsIfNeeded();
        continue;
      }

      try {
        await connection.service.checkHealth();
        await connection.service.reconnectEvents();
        connection.isConnected = true;
        onLog?.call('Agent reconnected: ${connection.profile.name}');
      } catch (e) {
        onLog?.call(
          'Agent reconnect failed for ${connection.profile.name}: $e',
        );
      }
    }
    notifyListeners();
  }

  Future<void> _loadMetadata(AgentConnection connection) async {
    connection.isLoadingMetadata = true;
    notifyListeners();

    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        connection.service.getCommands(),
        connection.service.getAgents(),
        connection.service.getProviders(),
        connection.service.getConfigProviders(),
      ]);

      connection.availableCommands = results[0]! as List<Command>;
      connection.availableAgents = results[1]! as List<Agent>;
      connection.providerInfo = results[2]! as ProviderListResponse;
      connection.configProviders = results[3]! as ConfigProvidersResponse;
      connection.modelOptions = deriveModelOptions(
        providerInfo: connection.providerInfo,
        configProviders: connection.configProviders,
      );
    } catch (e) {
      onLog?.call('Agent metadata load failed: $e');
    } finally {
      connection.isLoadingMetadata = false;
      notifyListeners();
    }
  }

  Future<void> _reloadMessages(String connectionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;
    final raw =
        await connection.service.getRawMessages(connection.activeSessionId!);
    connection.messages = raw.map(mapV2Message).toList();
    _applyMessageListUsage(connection, raw);
    notifyListeners();
  }

  void _applyMessageListUsage(
    AgentConnection connection,
    List<Map<String, dynamic>> raw,
  ) {
    final totals = sumV2MessageUsage(raw);
    connection.sessionInputTokens = totals.inputTokens;
    connection.sessionOutputTokens = totals.outputTokens;
    if (totals.cost != null && totals.cost! > 0) {
      connection.sessionCost = totals.cost;
    }
  }

  void _applyUsageEvent(AgentConnection connection, Map<String, dynamic> data) {
    final snapshot = extractV2Usage(data);
    if (snapshot == null) return;
    if (snapshot.inputTokens > 0 || snapshot.outputTokens > 0) {
      connection.sessionInputTokens = snapshot.inputTokens;
      connection.sessionOutputTokens = snapshot.outputTokens;
    }
    if (snapshot.cost != null) {
      connection.sessionCost = snapshot.cost;
    }
  }

  void _handleEvent(String connectionId, Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == null) return;

    final properties = event['properties'];
    final props = properties is Map<String, dynamic>
        ? properties
        : properties is Map
            ? Map<String, dynamic>.from(properties)
            : <String, dynamic>{};

    if (shouldIgnoreAgentEvent(type)) {
      return;
    }

    if (type == 'permission.asked' ||
        (type.contains('permission') &&
            !type.contains('reply') &&
            !type.contains('list') &&
            !type.contains('saved'))) {
      final connection = _findConnection(connectionId);
      if (connection == null) return;
      final permissionId =
          props['permissionID'] as String? ?? props['id'] as String? ?? '';
      if (permissionId.isEmpty) return;
      _pendingPermission = AgentPermissionRequest(
        connectionId: connectionId,
        sessionId: props['sessionID'] as String? ??
            props['sessionId'] as String? ??
            '',
        permissionId: permissionId,
        message: props['message'] as String? ??
            props['description'] as String? ??
            props['action'] as String? ??
            'Permission requested',
        service: connection.service,
      );
      notifyListeners();
      return;
    }

    if (type == 'session.usage.updated' || type == 'session.usage.recorded') {
      final connection = _findConnection(connectionId);
      if (connection == null) return;
      final data = props['data'];
      if (data is Map) {
        _applyUsageEvent(connection, Map<String, dynamic>.from(data));
      } else {
        _applyUsageEvent(connection, props);
      }
      notifyListeners();
    }

    if (shouldReloadMessagesForEvent(type)) {
      _scheduleReloadMessages(connectionId);
    }
    if (shouldRefreshSessionsForEvent(type)) {
      // ignore: unawaited_futures
      refreshSessions(connectionId);
    }
  }

  void _scheduleReloadMessages(String connectionId) {
    _reloadDebounce[connectionId]?.cancel();
    _reloadDebounce[connectionId] = Timer(
      const Duration(milliseconds: 200),
      () {
        // ignore: unawaited_futures
        _coalescedReloadMessages(connectionId);
      },
    );
  }

  Future<void> _coalescedReloadMessages(String connectionId) async {
    if (_reloadInFlight.contains(connectionId)) {
      _reloadQueued.add(connectionId);
      return;
    }
    _reloadInFlight.add(connectionId);
    try {
      await _reloadMessages(connectionId);
    } finally {
      _reloadInFlight.remove(connectionId);
      if (_reloadQueued.remove(connectionId)) {
        _scheduleReloadMessages(connectionId);
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _reloadDebounce.values) {
      timer.cancel();
    }
    _reloadDebounce.clear();
    for (final connection in _connections) {
      connection.disposeSubscriptions();
      connection.service.dispose();
    }
    _connections.clear();
    super.dispose();
  }
}

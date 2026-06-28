import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/agent_connection.dart';
import '../models/agent_permission_request.dart';
import '../models/ssh_profile.dart';
import '../services/config_service.dart';
import '../services/opencode_connection_service.dart';
import '../utils/agent_session_utils.dart';

class AgentProvider extends ChangeNotifier {
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

  Future<AgentConnection> connectFromProfile(SSHProfile profile) async {
    final username =
        profile.username.isNotEmpty ? profile.username : 'opencode';
    final service = OpenCodeConnectionService(
      baseUrl: profile.agentBaseUrl,
      username: username,
      password: profile.password ?? '',
    );

    try {
      await service.connect();
      final sessions = sortSessionsByUpdatedDesc(await service.getSessions());
      final connection = AgentConnection(
        id: const Uuid().v4(),
        profile: profile,
        service: service,
        sessions: sessions,
        isConnected: true,
      );

      service.events.listen((event) => _handleEvent(connection.id, event));

      _connections.add(connection);
      _activeConnectionId = connection.id;
      onLog?.call(
        'Agent connected: ${profile.name} (${profile.agentBaseUrl})',
      );
      notifyListeners();
      return connection;
    } catch (e) {
      service.dispose();
      rethrow;
    }
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
      username: username,
      password: password,
      agentPort: Uri.parse(url).port == 0 ? 5000 : Uri.parse(url).port,
      useHttps: url.startsWith('https'),
    );
    return connectFromProfile(profile);
  }

  Future<AgentConnection> connectToLocalDesktop({
    required int port,
    String password = '',
  }) async {
    final profile = SSHProfile(
      name: 'Local Desktop',
      host: '127.0.0.1',
      username: 'opencode',
      password: password,
      agentPort: port,
    );

    const username = 'opencode';
    final service = OpenCodeConnectionService(
      baseUrl: profile.agentBaseUrl,
      username: username,
      password: password,
    );

    try {
      await service.connect();

      String? directory = await ConfigService.getAgentLastDirectory();
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

      service.events.listen((event) => _handleEvent(connection.id, event));

      _connections.add(connection);
      _activeConnectionId = connection.id;
      onLog?.call(
        'Agent connected locally (${profile.agentBaseUrl})',
      );
      notifyListeners();
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
    await ConfigService.saveAgentLastDirectory(path);
    await refreshSessions(connectionId);
    onLog?.call('Agent directory set: $path');
  }

  Future<void> disconnect(String connectionId) async {
    final index = _connections.indexWhere((c) => c.id == connectionId);
    if (index == -1) return;

    final connection = _connections[index];
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
    connection.isLoadingMessages = true;
    notifyListeners();

    try {
      connection.messages = await connection.service.getMessages(sessionId);
    } finally {
      connection.isLoadingMessages = false;
      notifyListeners();
    }
  }

  void clearActiveSession(String connectionId) {
    final connection = _findConnection(connectionId);
    if (connection == null) return;
    connection.activeSessionId = null;
    connection.messages = [];
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

  Future<void> sendPrompt(String connectionId, String text) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    connection.isSending = true;
    notifyListeners();

    try {
      await connection.service.sendMessageAsync(
        connection.activeSessionId!,
        trimmed,
      );
      onLog?.call('Agent prompt sent to ${connection.profile.name}');
    } finally {
      connection.isSending = false;
      notifyListeners();
    }
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

  Future<void> _reloadMessages(String connectionId) async {
    final connection = _findConnection(connectionId);
    if (connection == null || connection.activeSessionId == null) return;
    connection.messages =
        await connection.service.getMessages(connection.activeSessionId!);
    notifyListeners();
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

    if (type == 'server.heartbeat' || type == 'server.connected') {
      return;
    }

    if (type == 'permission.asked') {
      final connection = _findConnection(connectionId);
      if (connection == null) return;
      _pendingPermission = AgentPermissionRequest(
        connectionId: connectionId,
        sessionId: props['sessionID'] as String? ?? '',
        permissionId: props['permissionID'] as String? ?? '',
        message: props['message'] as String? ??
            props['description'] as String? ??
            'Permission requested',
        service: connection.service,
      );
      notifyListeners();
      return;
    }

    if (type.startsWith('session.') ||
        type.startsWith('message.') ||
        type.contains('message')) {
      // ignore: unawaited_futures
      _reloadMessages(connectionId);
      if (type.startsWith('session.')) {
        // ignore: unawaited_futures
        refreshSessions(connectionId);
      }
    }
  }

  @override
  void dispose() {
    for (final connection in _connections) {
      connection.service.dispose();
    }
    _connections.clear();
    super.dispose();
  }
}

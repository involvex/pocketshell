import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import 'dart:io' show SocketException;

import '../models/ssh_profile.dart';
import '../models/known_host.dart';
import '../models/port_forward_rule.dart';
import '../services/config_repository.dart';
import '../services/network_discovery_service.dart';
import '../services/app_lifecycle_service.dart';
import '../services/secure_storage_service.dart';
import '../services/ssh_local_forward.dart';
import '../services/widget_profile_service.dart';
import '../services/host_key_verification_service.dart';
import '../models/session_entry.dart';
import '../utils/jump_host_utils.dart';
import '../utils/prefs_secret_audit.dart';
import '../utils/session_manager.dart';
import '../utils/ssh_auth_utils.dart';
import '../utils/error_redaction.dart';
import '../utils/startup_command_log.dart';
import '../utils/terminal_context.dart';
import '../utils/terminal_enter_mapping.dart';
import 'connection_log_notifier.dart';

class SSHProvider extends ChangeNotifier {
  SSHProvider({ConfigRepository? config})
      : _config = config ?? ConfigServiceRepository();

  final ConfigRepository _config;
  Timer? _idleTimer;

  /// Starts the periodic idle check lazily so widget tests that instantiate
  /// a provider without sessions never leave a pending timer.
  void _ensureIdleTimer() {
    _idleTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      // ignore: unawaited_futures
      checkIdleTimeouts();
    });
  }

  // sessions container
  final List<SessionEntry> sessions = <SessionEntry>[];
  String? activeSessionId;

  /// Synced from [SettingsProvider] for startup / paste newline mapping.
  TerminalEnterSends terminalEnterSends = TerminalEnterSends.cr;

  final ConnectionLogNotifier connectionLogNotifier = ConnectionLogNotifier();

  List<String> get connectionLog => connectionLogNotifier.lines;

  /// One-shot sticky modifiers for mobile (Ctrl/Alt buttons in the accessory
  /// panel). Armed by tapping the toggle, consumed by the next keypress —
  /// whether that key comes from the panel or the soft keyboard (Gboard).
  /// Soft-keyboard input bypasses panel state entirely and funnels through
  /// [Terminal.onOutput], where [_applyPendingModifiers] applies them.
  bool _pendingCtrl = false;
  bool _pendingAlt = false;

  /// Locked modifiers stay armed across keypresses until tapped again.
  /// Armed by double-tapping the toggle (two taps within
  /// [lockDoubleTapWindow]); useful for repeated combos like `Ctrl+C`.
  bool _lockedCtrl = false;
  bool _lockedAlt = false;
  DateTime? _lastCtrlToggle;
  DateTime? _lastAltToggle;

  /// Double-tap window for engaging the modifier lock. Public for testing.
  static const Duration lockDoubleTapWindow = Duration(milliseconds: 400);

  bool get pendingCtrl => _pendingCtrl;
  bool get pendingAlt => _pendingAlt;
  bool get hasPendingModifiers => _pendingCtrl || _pendingAlt;
  bool get lockedCtrl => _lockedCtrl;
  bool get lockedAlt => _lockedAlt;

  void togglePendingCtrl() {
    final DateTime now = DateTime.now();
    if (_lockedCtrl) {
      _lockedCtrl = false;
      _pendingCtrl = false;
    } else if (_pendingCtrl &&
        _lastCtrlToggle != null &&
        now.difference(_lastCtrlToggle!) <= lockDoubleTapWindow) {
      _lockedCtrl = true;
    } else {
      _pendingCtrl = !_pendingCtrl;
    }
    _lastCtrlToggle = now;
    notifyListeners();
  }

  void togglePendingAlt() {
    final DateTime now = DateTime.now();
    if (_lockedAlt) {
      _lockedAlt = false;
      _pendingAlt = false;
    } else if (_pendingAlt &&
        _lastAltToggle != null &&
        now.difference(_lastAltToggle!) <= lockDoubleTapWindow) {
      _lockedAlt = true;
    } else {
      _pendingAlt = !_pendingAlt;
    }
    _lastAltToggle = now;
    notifyListeners();
  }

  void clearPendingModifiers() {
    var changed = false;
    if (_pendingCtrl && !_lockedCtrl) {
      _pendingCtrl = false;
      changed = true;
    }
    if (_pendingAlt && !_lockedAlt) {
      _pendingAlt = false;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  List<SSHProfile> profiles = <SSHProfile>[];
  SSHProfile? lastSession;
  List<String> discoveredHosts = <String>[];
  bool isScanning = false;

  /// UI hook for first-trust decisions. Set by screens that have a
  /// [BuildContext] (e.g. HomeScreen). When null, unknown keys are **denied**
  /// (fail closed). Already-trusted hosts still reconnect without a prompt;
  /// mismatches always fail closed.
  Future<bool> Function(KnownHostPrompt prompt)? onVerifyHostKeyPrompt;

  /// UI hook invoked when a changed host key blocks a connection, so the
  /// active screen can show the warning dialog.
  void Function({
    required String host,
    required int port,
    required String expectedFingerprint,
    required String presentedFingerprint,
  })? onHostKeyMismatch;

  /// UI hook for SSH keyboard-interactive prompts (2FA/TOTP). Return null to
  /// cancel / skip the method. When null, keyboard-interactive is not offered.
  Future<List<String>?> Function(SSHUserInfoRequest request)?
      onUserInfoRequest;

  Future<void> loadConfig() async {
    var profileData = await _config.getProfiles();
    final migratedProfiles =
        await SecureStorageService.migrateProfilePasswords(profileData);
    final migratedAgentProfiles =
        await SecureStorageService.migrateAgentPasswords(migratedProfiles);
    if (!identical(migratedAgentProfiles, profileData)) {
      await _config.saveProfiles(migratedAgentProfiles);
      profileData = migratedAgentProfiles;
    }
    if (mapListContainsLegacySecrets(profileData)) {
      addLog(
        'Warning: profile secrets are still in local prefs — '
        'secure storage may be locked; reconnect after unlocking the device',
      );
    }

    profiles = <SSHProfile>[];
    for (final raw in profileData) {
      profiles.add(await _hydrateProfile(SSHProfile.fromJson(raw)));
    }

    final keyData = await _config.getSSHKeys();
    final migratedKeys =
        await SecureStorageService.migrateKeyPassphrases(keyData);
    final migratedPrivKeys =
        await SecureStorageService.migratePrivateKeys(migratedKeys);
    if (!identical(migratedPrivKeys, keyData)) {
      await _config.saveSSHKeys(migratedPrivKeys);
    }
    if (mapListContainsLegacySecrets(migratedPrivKeys)) {
      addLog(
        'Warning: SSH key material is still in local prefs — '
        'secure storage may be locked',
      );
    }

    final sessionData = await _config.getLastSession();
    if (sessionData != null) {
      lastSession = await _hydrateProfile(SSHProfile.fromJson(sessionData));
    }

    await WidgetProfileService.syncProfiles(profiles);
    notifyListeners();
  }

  Future<SSHProfile> _hydrateProfile(SSHProfile profile) async {
    final securePassword =
        await SecureStorageService.readProfilePassword(profile.id);
    final secureAgentPassword =
        await SecureStorageService.readAgentPassword(profile.id);
    var hydrated = profile;
    if (securePassword != null && securePassword.isNotEmpty) {
      hydrated = hydrated.copyWith(password: securePassword);
    }
    if (secureAgentPassword != null && secureAgentPassword.isNotEmpty) {
      hydrated = hydrated.copyWith(agentPassword: secureAgentPassword);
    }
    return hydrated;
  }

  Future<void> saveProfile(SSHProfile profile) async {
    if (createsJumpCycle(profiles, profile.id, profile.jumpProfileId)) {
      throw StateError('Jump host cycle detected');
    }

    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await SecureStorageService.writeProfilePassword(
      profile.id,
      profile.password,
    );
    await SecureStorageService.writeAgentPassword(
      profile.id,
      profile.agentPassword,
    );
    await _config.saveProfiles(profiles.map((e) => e.toJson()).toList());
    await WidgetProfileService.syncProfiles(profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((p) => p.id == id);
    await SecureStorageService.deleteProfilePassword(id);
    await SecureStorageService.deleteAgentPassword(id);
    await _config.saveProfiles(profiles.map((e) => e.toJson()).toList());
    await WidgetProfileService.syncProfiles(profiles);
    notifyListeners();
  }

  Future<void> saveLastSession(SSHProfile profile) async {
    lastSession = profile;
    await SecureStorageService.writeProfilePassword(
      profile.id,
      profile.password,
    );
    await SecureStorageService.writeAgentPassword(
      profile.id,
      profile.agentPassword,
    );
    await _config.saveLastSession(profile.toJson());
    notifyListeners();
  }

  void setTerminalEnterSends(TerminalEnterSends mapping) {
    if (terminalEnterSends == mapping) {
      return;
    }
    terminalEnterSends = mapping;
  }

  Future<void> scanNetwork() async {
    isScanning = true;
    discoveredHosts = <String>[];
    notifyListeners();

    discoveredHosts = await NetworkDiscoveryService.scanNetwork();

    isScanning = false;
    notifyListeners();
  }

  Future<void> discoverHost(String host) async {
    final isOpen = await NetworkDiscoveryService.checkPortOpen(host, 22);
    if (isOpen && !discoveredHosts.contains(host)) {
      discoveredHosts.add(host);
      notifyListeners();
    }
  }

  // Session APIs
  SessionEntry createSessionFromProfile(SSHProfile profile, {String? name}) {
    if (sessions.length >= 4) {
      throw StateError('Maximum number of sessions (4) reached');
    }
    _ensureIdleTimer();
    final entry = SessionEntry(name: name ?? profile.name, profile: profile);
    sessions.add(entry);
    activeSessionId = entry.id;
    notifyListeners();
    return entry;
  }

  void switchActiveSession(String sessionId) {
    if (activeSessionId == sessionId) return;
    if (!sessions.any((s) => s.id == sessionId)) return;
    activeSessionId = sessionId;
    notifyListeners();
  }

  SessionEntry? get activeSession {
    if (activeSessionId == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == activeSessionId);
    } catch (_) {
      return sessions.isNotEmpty ? sessions.first : null;
    }
  }

  /// Finds a connected SSH client session matching [host] (localhost aliases).
  SessionEntry? findConnectedSessionForHost(String host) {
    for (final session in sessions) {
      if (!session.isConnected || session.client == null) continue;
      if (_hostsMatch(session.profile.host, host)) {
        return session;
      }
    }
    return null;
  }

  /// Prefers a connected session for [profile.id], else any session to the host.
  SessionEntry? findConnectedSessionForProfile(SSHProfile profile) {
    for (final session in sessions) {
      if (!session.isConnected || session.client == null) continue;
      if (session.profile.id == profile.id) {
        return session;
      }
    }
    return findConnectedSessionForHost(profile.host);
  }

  bool _hostsMatch(String a, String b) {
    final na = a.toLowerCase();
    final nb = b.toLowerCase();
    if (na == nb) return true;
    const localHosts = <String>{'localhost', '127.0.0.1', '::1'};
    return localHosts.contains(na) && localHosts.contains(nb);
  }

  Future<void> connectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    final profile = entry.profile;
    SSHClient? jumpClient;

    try {
      addLog('Connecting to ${profile.host}:${profile.port}...');
      final auth = await resolveSshAuthMaterial(profile);
      final canKeyboardInteractive = onUserInfoRequest != null;
      if (!auth.hasKeyAuth &&
          !auth.hasPasswordAuth &&
          !canKeyboardInteractive) {
        throw StateError(
          'No credentials: set a password or select an SSH key for this profile',
        );
      }

      final socketAndJump = await _openSocketForProfile(profile);
      jumpClient = socketAndJump.jumpClient;
      final socket = socketAndJump.socket;

      final client = SSHClient(
        socket,
        username: profile.username,
        identities: auth.identities,
        onPasswordRequest: auth.hasPasswordAuth ? () => auth.password! : null,
        onUserInfoRequest: canKeyboardInteractive
            ? (request) async {
                final hook = onUserInfoRequest;
                if (hook == null) {
                  return null;
                }
                addLog(
                  'Keyboard-interactive auth for ${profile.host}:${profile.port}',
                );
                return hook(request);
              }
            : null,
        onUserauthBanner: (banner) {
          final trimmed = banner.trim();
          if (trimmed.isNotEmpty) {
            addLog('SSH banner: $trimmed');
          }
        },
        keepAliveInterval: const Duration(seconds: 15),
        onVerifyHostKey: (type, fingerprintBytes) => _verifyHostKey(
          host: profile.host,
          port: profile.port,
          type: type,
          fingerprintBytes: fingerprintBytes,
        ),
      );

      final shell = await client.shell(
        pty: const SSHPtyConfig(width: 80, height: 24),
      );

      entry.client = client;
      entry.jumpClient = jumpClient;
      entry.shellSession = shell;

      shell.stdout.listen((data) {
        entry.terminal.write(utf8.decode(data));
      });
      shell.stderr.listen((data) {
        entry.terminal.write(utf8.decode(data));
      });
      entry.terminal.onOutput = (data) {
        entry.touch();
        final String transformed = _applyPendingModifiers(data);
        shell.stdin.add(utf8.encode(transformed));
      };

      entry.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        entry.shellSession
            ?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      unawaited(shell.done.then((_) async {
        await _onShellDone(entry);
      }));

      entry.isConnected = true;
      entry.lastError = null;
      entry.shouldReconnectOnResume = true;
      entry.reconnectAttempts = 0;
      entry.touch();
      addLog('Connected: ${entry.name}');
      await _startEnabledForwards(entry);
      notifyListeners();

      final effectiveStartup = resolveStartupCommand(
        sessionManager: profile.sessionManager,
        startupCommand: profile.startupCommand,
      );
      if (effectiveStartup != null && effectiveStartup.isNotEmpty) {
        final trimmed = effectiveStartup.trim();
        final isGit = trimmed.toLowerCase().startsWith('git ');
        if (isGit) {
          final escaped = effectiveStartup.replaceAll("'", "''");
          const gitFullPath = r'C:\Program Files\Git\cmd\git.exe';
          final psCmd =
              "powershell -NoProfile -Command \"& '$gitFullPath' $escaped\"";
          try {
            shell.stdin.add(
              utf8.encode(withEnterSuffix(psCmd, terminalEnterSends)),
            );
            addLog(
              'Executed startup command via PowerShell wrapper: '
              '${redactStartupCommandLog(psCmd)}',
            );
          } catch (_) {
            shell.stdin.add(
              utf8.encode(
                withEnterSuffix(effectiveStartup, terminalEnterSends),
              ),
            );
            addLog(
              'Fallback: Executed startup command raw: '
              '${redactStartupCommandLog(effectiveStartup)}',
            );
          }
        } else {
          shell.stdin.add(
            utf8.encode(
              withEnterSuffix(effectiveStartup, terminalEnterSends),
            ),
          );
          addLog(
            'Executed startup command: '
            '${redactStartupCommandLog(effectiveStartup)}',
          );
        }
      }
    } catch (e) {
      final String safeError = redactErrorForDisplay(e);
      addLog(
        'Connection failed for ${profile.host}:${profile.port} — $safeError',
      );
      entry.isConnected = false;
      entry.lastError = safeError;
      await entry.closeForwards();
      entry.client?.close();
      entry.jumpClient?.close();
      jumpClient?.close();
      entry.client = null;
      entry.jumpClient = null;
      entry.shellSession = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Opens a direct or jump-host [SSHSocket] for [profile].
  Future<({SSHSocket socket, SSHClient? jumpClient})> _openSocketForProfile(
    SSHProfile profile,
  ) async {
    final jumpId = profile.jumpProfileId;
    if (jumpId == null || jumpId.isEmpty) {
      final socket = await SSHSocket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 20),
      );
      return (socket: socket, jumpClient: null);
    }

    if (createsJumpCycle(profiles, profile.id, jumpId)) {
      throw StateError('Jump host cycle detected');
    }

    SSHProfile? jumpProfile;
    for (final p in profiles) {
      if (p.id == jumpId) {
        jumpProfile = p;
        break;
      }
    }
    if (jumpProfile == null) {
      throw StateError('Jump host profile not found');
    }
    if (jumpProfile.jumpProfileId != null &&
        jumpProfile.jumpProfileId!.isNotEmpty) {
      // Nested multi-hop is not supported in 1.4.0 — require a direct bastion.
      throw StateError(
        'Jump host "${jumpProfile.name}" itself uses a jump host; '
        'nested ProxyJump is not supported',
      );
    }

    addLog(
      'Connecting via jump host ${jumpProfile.name} '
      '(${jumpProfile.host}:${jumpProfile.port})...',
    );
    final jumpAuth = await resolveSshAuthMaterial(jumpProfile);
    final canKeyboardInteractive = onUserInfoRequest != null;
    if (!jumpAuth.hasKeyAuth &&
        !jumpAuth.hasPasswordAuth &&
        !canKeyboardInteractive) {
      throw StateError(
        'Jump host has no credentials: set a password or SSH key',
      );
    }

    final jumpSocket = await SSHSocket.connect(
      jumpProfile.host,
      jumpProfile.port,
      timeout: const Duration(seconds: 20),
    );
    final jumpClient = SSHClient(
      jumpSocket,
      username: jumpProfile.username,
      identities: jumpAuth.identities,
      onPasswordRequest:
          jumpAuth.hasPasswordAuth ? () => jumpAuth.password! : null,
      onUserInfoRequest: canKeyboardInteractive
          ? (request) async {
              final hook = onUserInfoRequest;
              if (hook == null) {
                return null;
              }
              addLog(
                'Keyboard-interactive auth for jump '
                '${jumpProfile!.host}:${jumpProfile.port}',
              );
              return hook(request);
            }
          : null,
      keepAliveInterval: const Duration(seconds: 15),
      onVerifyHostKey: (type, fingerprintBytes) => _verifyHostKey(
        host: jumpProfile!.host,
        port: jumpProfile.port,
        type: type,
        fingerprintBytes: fingerprintBytes,
      ),
    );

    await jumpClient.authenticated;
    final tunneled = await jumpClient.forwardLocal(profile.host, profile.port);
    addLog(
      'Opened jump tunnel to ${profile.host}:${profile.port} via '
      '${jumpProfile.name}',
    );
    return (socket: tunneled, jumpClient: jumpClient);
  }

  Future<bool> _verifyHostKey({
    required String host,
    required int port,
    required String type,
    required List<int> fingerprintBytes,
  }) async {
    final fingerprint = String.fromCharCodes(fingerprintBytes);
    final verifier = HostKeyVerificationService(_config);
    final stored = await verifier.loadHosts();
    final decision = verifier.evaluate(
      stored: stored,
      host: host,
      port: port,
      keyType: type,
      fingerprint: fingerprint,
    );
    switch (decision) {
      case HostKeyDecision.trusted:
        return true;
      case HostKeyDecision.mismatch:
        final expected = stored
            .where((h) => h.matches(host, port))
            .map((h) => h.fingerprint)
            .join(', ');
        addLog(
          'Host key changed for $host:$port — connection blocked',
        );
        onHostKeyMismatch?.call(
          host: host,
          port: port,
          expectedFingerprint: expected.isEmpty ? '(unknown)' : expected,
          presentedFingerprint: fingerprint,
        );
        return false;
      case HostKeyDecision.unknown:
        final prompt = KnownHostPrompt(
          host: host,
          port: port,
          keyType: type,
          fingerprint: fingerprint,
        );
        final trusted = await confirmUnknownHostKey(
          hook: onVerifyHostKeyPrompt,
          prompt: prompt,
        );
        if (trusted) {
          await verifier.trustHost(prompt);
          addLog(
            'Trusted new host key for $host:$port ($type $fingerprint)',
          );
          return true;
        }
        addLog('Rejected unknown host key for $host:$port');
        return false;
    }
  }

  Future<void> _startEnabledForwards(SessionEntry entry) async {
    final client = entry.client;
    if (client == null) {
      return;
    }
    for (final rule in entry.profile.localForwards) {
      if (!rule.enabled || rule.localPort <= 0 || rule.remotePort <= 0) {
        continue;
      }
      try {
        await startPortForward(entry.id, rule);
      } catch (e) {
        addLog(
          'Local forward ${rule.localPort}→'
          '${rule.remoteHost}:${rule.remotePort} failed: $e',
        );
      }
    }
  }

  /// Starts a named local forward on [sessionId]. Throws [SocketException]
  /// when the local port is already bound.
  Future<ActivePortForward> startPortForward(
    String sessionId,
    PortForwardRule rule,
  ) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    final client = entry.client;
    if (client == null || !entry.isConnected) {
      throw StateError('Session is not connected');
    }
    // Stop an existing forward for the same rule id or local port.
    await stopPortForward(sessionId, ruleId: rule.id, localPort: rule.localPort);

    try {
      final forward = await SshLocalForward.start(
        client: client,
        localPort: rule.localPort,
        remoteHost: rule.remoteHost,
        remotePort: rule.remotePort,
      );
      final active = ActivePortForward(rule: rule, forward: forward);
      entry.activeForwards.add(active);
      addLog(
        'Local forward listening on 127.0.0.1:${forward.localPort} → '
        '${rule.remoteHost}:${rule.remotePort}'
        '${rule.label.isNotEmpty ? ' (${rule.label})' : ''}',
      );
      notifyListeners();
      return active;
    } on SocketException catch (e) {
      addLog('Local port ${rule.localPort} is already in use');
      throw SocketException(
        'Local port ${rule.localPort} is already in use',
        osError: e.osError,
        address: e.address,
        port: rule.localPort,
      );
    }
  }

  Future<void> stopPortForward(
    String sessionId, {
    String? ruleId,
    int? localPort,
  }) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    final toClose = entry.activeForwards
        .where(
          (a) =>
              (ruleId != null && a.rule.id == ruleId) ||
              (localPort != null && a.forward.localPort == localPort),
        )
        .toList();
    for (final active in toClose) {
      await active.forward.close();
      entry.activeForwards.remove(active);
      addLog(
        'Stopped local forward 127.0.0.1:${active.forward.localPort}',
      );
    }
    if (toClose.isNotEmpty) {
      notifyListeners();
    }
  }

  Future<void> reconnectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    entry.suppressAutoReconnect = true;
    try {
      await entry.closeForwards();
      entry.shellSession?.close();
      entry.client?.close();
      entry.jumpClient?.close();
      entry.shellSession = null;
      entry.client = null;
      entry.jumpClient = null;
      // Preserve scrollback: reuse the existing Terminal buffer.
      entry.terminal.write('\r\n\x1b[90m--- reconnecting ---\x1b[0m\r\n');
      await connectSession(sessionId);
    } finally {
      entry.suppressAutoReconnect = false;
    }
  }

  Future<void> disconnectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId,
        orElse: () => throw StateError('Session not found'));
    entry.shouldReconnectOnResume = false;
    entry.suppressAutoReconnect = true;
    entry.reconnectAttempts = 0;
    try {
      await entry.closeForwards();
      entry.shellSession?.close();
      entry.client?.close();
      entry.jumpClient?.close();
      entry.jumpClient = null;
      entry.isConnected = false;
      entry.disconnectedWhileBackgrounded = false;
      entry.terminal = Terminal();
      notifyListeners();
    } finally {
      entry.suppressAutoReconnect = false;
    }
  }

  /// Handles a closed PTY: clean remote `exit` stays down; link drops
  /// auto-reconnect while the app is foregrounded (resume still covers
  /// background drops via [AppLifecycleService]).
  Future<void> _onShellDone(SessionEntry entry) async {
    addLog('Session ${entry.name} closed');
    if (entry.suppressAutoReconnect) {
      entry.isConnected = false;
      await entry.closeForwards();
      notifyListeners();
      return;
    }

    final client = entry.client;
    final cleanExit = client != null && !client.isClosed;
    if (cleanExit) {
      // Remote shell exited (e.g. user typed `exit`) while TCP is still up.
      entry.shouldReconnectOnResume = false;
      entry.reconnectAttempts = 0;
      try {
        client.close();
      } catch (_) {}
      entry.jumpClient?.close();
      entry.client = null;
      entry.jumpClient = null;
      entry.shellSession = null;
      entry.isConnected = false;
      await entry.closeForwards();
      notifyListeners();
      return;
    }

    if (AppLifecycleService.isInBackground) {
      entry.disconnectedWhileBackgrounded = true;
    }
    entry.isConnected = false;
    entry.shellSession = null;
    await entry.closeForwards();
    notifyListeners();

    if (entry.shouldReconnectOnResume && !AppLifecycleService.isInBackground) {
      unawaited(_foregroundReconnectWithBackoff(entry));
    }
  }

  static const int kMaxForegroundReconnectAttempts = 5;

  Future<void> _foregroundReconnectWithBackoff(SessionEntry entry) async {
    while (entry.shouldReconnectOnResume &&
        !entry.isConnected &&
        entry.reconnectAttempts < kMaxForegroundReconnectAttempts) {
      if (AppLifecycleService.isInBackground) {
        entry.disconnectedWhileBackgrounded = true;
        return;
      }
      entry.reconnectAttempts++;
      final delaySeconds =
          1 << (entry.reconnectAttempts - 1); // 1, 2, 4, 8, 16
      addLog(
        'Reconnect ${entry.name}: attempt '
        '${entry.reconnectAttempts}/$kMaxForegroundReconnectAttempts '
        'in ${delaySeconds}s',
      );
      notifyListeners();
      await Future<void>.delayed(Duration(seconds: delaySeconds));
      if (!entry.shouldReconnectOnResume || entry.isConnected) {
        return;
      }
      if (AppLifecycleService.isInBackground) {
        entry.disconnectedWhileBackgrounded = true;
        return;
      }
      try {
        await reconnectSession(entry.id);
        return;
      } catch (e) {
        addLog(
          'Reconnect failed for ${entry.name}: ${redactErrorForDisplay(e)}',
        );
      }
    }
    if (!entry.isConnected && entry.shouldReconnectOnResume) {
      addLog(
        'Gave up reconnecting ${entry.name} after '
        '$kMaxForegroundReconnectAttempts attempts',
      );
      notifyListeners();
    }
  }

  void removeSession(String sessionId) {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final entry = sessions.removeAt(idx);
    entry.disposeRuntime();
    if (activeSessionId == sessionId) {
      activeSessionId = sessions.isNotEmpty ? sessions.first.id : null;
    }
    notifyListeners();
  }

  Future<List<KnownHost>> getKnownHosts() async {
    return HostKeyVerificationService(_config).loadHosts();
  }

  Future<String?> getTrustedFingerprint(String host, int port) async {
    final hosts = await getKnownHosts();
    final matches = hosts.where((h) => h.matches(host, port)).toList();
    if (matches.isEmpty) return null;
    return matches.first.fingerprint;
  }

  Future<void> forgetKnownHost(String host, int port) async {
    await HostKeyVerificationService(_config).removeHost(host, port);
    addLog('Forgot trusted host key for $host:$port');
    notifyListeners();
  }

  Future<void> connectClient({
    required String host,
    required int port,
    required String username,
    required String password,
    String? startupCommand,
  }) async {
    // Backwards-compatible wrapper: create a temp profile and session
    final profile = SSHProfile(
        name: 'Last Session',
        host: host,
        port: port,
        username: username,
        password: password,
        startupCommand: startupCommand);
    final entry = createSessionFromProfile(profile);
    await connectSession(entry.id);
  }

  void sendControlCharacter(int charCode) {
    final entry = activeSession;
    if (entry != null && entry.shellSession != null && entry.isConnected) {
      entry.shellSession!.stdin.add(Uint8List.fromList([charCode]));
      addLog('Sent Ctrl+${_getCtrlLabel(charCode)}');
    }
  }

  /// Sends a letter with optional Ctrl/Alt modifiers through the terminal
  /// emulator so encoding matches hardware-keyboard input
  /// (`Ctrl+X` -> `0x18`, `Alt+F` -> `ESC F`).
  /// Returns true when the terminal handled the combination.
  /// This is the mobile/sticky-modifier path: soft-keyboard typing bypasses
  /// any panel state, so callers must route armed modifiers through here
  /// instead of sending the plain letter.
  bool sendModifiedLetter(
    String letter, {
    bool ctrl = false,
    bool alt = false,
  }) {
    final entry = activeSession;
    if (entry == null || !entry.isConnected) {
      return false;
    }
    if (letter.length != 1) {
      return false;
    }
    final int code = letter.toLowerCase().codeUnitAt(0);
    if (code < 97 || code > 122) {
      return false;
    }
    final bool handled = entry.terminal.charInput(
      code,
      ctrl: ctrl,
      alt: alt,
    );
    if (handled) {
      entry.touch();
      if (ctrl) {
        addLog('Sent Ctrl+${letter.toUpperCase()}');
      } else if (alt) {
        addLog('Sent Alt+${letter.toUpperCase()}');
      }
      return true;
    }
    return false;
  }

  /// Sends a terminal key with optional modifiers through `keyInput`,
  /// applying keytab encoding (e.g. `Ctrl+Up` -> `\E[1;5A`).
  /// Returns true when the terminal handled the combination.
  bool sendTerminalKey(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    final entry = activeSession;
    if (entry == null || !entry.isConnected) {
      return false;
    }
    final bool handled = entry.terminal.keyInput(
      key,
      ctrl: ctrl,
      alt: alt,
      shift: shift,
    );
    if (handled) {
      entry.touch();
    }
    return handled;
  }

  void sendString(String data) {
    final entry = activeSession;
    if (entry != null && entry.shellSession != null && entry.isConnected) {
      final normalized = normalizeNewlines(data, terminalEnterSends);
      entry.shellSession!.stdin.add(utf8.encode(normalized));
    }
  }

  String getActiveTerminalContext(
      {int lineCount = kDefaultTerminalContextLines}) {
    final entry = activeSession;
    if (entry == null || !entry.isConnected) {
      return '';
    }
    return extractRecentTerminalOutput(
      entry.terminal,
      lineCount: lineCount,
    );
  }

  /// Applies armed sticky modifiers to raw terminal output. This is what makes
  /// `Ctrl`/`Alt` + a normal soft-keyboard (Gboard) key work: Gboard commits
  /// text straight to the terminal and never sees panel state, but everything
  /// funnels through `onOutput`, so the next single-character output is
  /// transformed here (`x` + pending Ctrl -> `0x18`, `f` + pending Alt ->
  /// `ESC F`) and the pending flags are consumed. Multi-character output
  /// (pastes, escape sequences) passes through untouched without consuming.
  /// Pure transform for sticky modifiers. Returns the encoded output for a
  /// single-character input, or null when the input is not transformable
  /// (multi-character output like pastes/escape sequences, or keys with no
  /// control encoding). Ctrl wins when both modifiers are armed.
  static String? transformStickyInput(
    String data, {
    required bool ctrl,
    required bool alt,
  }) {
    if (!ctrl && !alt) {
      return null;
    }
    if (data.length != 1) {
      return null;
    }
    final int code = data.codeUnitAt(0);
    final int lower = code >= 65 && code <= 90 ? code + 32 : code;
    if (ctrl) {
      if (lower >= 97 && lower <= 122) {
        return String.fromCharCode(lower - 96);
      }
      if (code == 32) {
        return String.fromCharCode(0);
      }
      if (code >= 91 && code <= 95) {
        return String.fromCharCode(code - 91 + 27);
      }
      return null;
    }
    if (lower >= 97 && lower <= 122) {
      return String.fromCharCodes(<int>[0x1b, lower - 97 + 65]);
    }
    return null;
  }

  String _applyPendingModifiers(String data) {
    if (!_pendingCtrl && !_pendingAlt) {
      return data;
    }
    final String? transformed = transformStickyInput(
      data,
      ctrl: _pendingCtrl,
      alt: _pendingAlt,
    );
    // Single-character input always consumes the armed modifiers (toggle
    // behaviour: active until the next key), even when it has no control
    // encoding — e.g. Ctrl+3 sends a plain 3.
    final bool consume = data.length == 1;
    final bool wasCtrl = _pendingCtrl;
    if (consume) {
      // Respects locks: locked modifiers stay armed across keypresses.
      clearPendingModifiers();
    }
    if (transformed != null) {
      if (wasCtrl) {
        final int code = data.codeUnitAt(0);
        final int lower = code >= 65 && code <= 90 ? code + 32 : code;
        final String label = (lower >= 97 && lower <= 122)
            ? String.fromCharCode(lower - 32)
            : data;
        addLog('Sent Ctrl+$label');
      } else {
        addLog('Sent Alt+${data.toUpperCase()}');
      }
      return transformed;
    }
    return data;
  }

  String _getCtrlLabel(int charCode) {
    if (charCode >= 1 && charCode <= 26) {
      return String.fromCharCode(64 + charCode);
    }
    switch (charCode) {
      case 9:
        return 'Tab';
      case 27:
        return 'Esc';
      default:
        return String.fromCharCode(charCode);
    }
  }

  void addLog(String message) {
    connectionLogNotifier.add(message);
  }

  void clearConnectionLog() {
    connectionLogNotifier.clear();
  }

  /// Reads the idle-timeout setting directly so background checks work
  /// without a [SettingsProvider] reference. Returns 0 when disabled.
  Future<int> _idleTimeoutMinutes() async {
    try {
      final settings = await _config.getSettings();
      return (settings['sessionIdleTimeoutMinutes'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Disconnects sessions idle longer than the configured timeout.
  /// Returns the number of sessions disconnected. Public for testing.
  Future<int> checkIdleTimeouts({DateTime? now}) async {
    final timeout = await _idleTimeoutMinutes();
    if (timeout <= 0) return 0;
    final current = now ?? DateTime.now();
    var disconnected = 0;
    for (final session in List<SessionEntry>.of(sessions)) {
      if (!session.isConnected) continue;
      final last = session.lastActivityAt;
      if (last == null) continue;
      if (current.difference(last).inMinutes >= timeout) {
        session.shellSession?.close();
        session.client?.close();
        session.isConnected = false;
        session.shouldReconnectOnResume = false;
        session.shellSession = null;
        session.client = null;
        disconnected++;
        addLog(
          'Idle timeout (${timeout}m): disconnected ${session.name}',
        );
      }
    }
    return disconnected;
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    connectionLogNotifier.dispose();
    for (final s in sessions) {
      s.disposeRuntime();
    }
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../models/ssh_profile.dart';
import '../models/known_host.dart';
import '../services/config_repository.dart';
import '../services/network_discovery_service.dart';
import '../services/app_lifecycle_service.dart';
import '../services/secure_storage_service.dart';
import '../services/widget_profile_service.dart';
import '../services/host_key_verification_service.dart';
import '../models/session_entry.dart';
import '../utils/session_manager.dart';
import '../utils/ssh_auth_utils.dart';
import '../utils/terminal_context.dart';
import '../utils/terminal_enter_mapping.dart';

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

  List<String> connectionLog = [];

  List<SSHProfile> profiles = <SSHProfile>[];
  SSHProfile? lastSession;
  List<String> discoveredHosts = <String>[];
  bool isScanning = false;

  /// UI hook for first-trust decisions. Set by screens that have a
  /// [BuildContext] (e.g. HomeScreen). When null, unknown keys are still
  /// trusted once (TOFU) so background reconnects keep working, but mismatches
  /// always fail closed.
  Future<bool> Function(KnownHostPrompt prompt)? onVerifyHostKeyPrompt;

  /// UI hook invoked when a changed host key blocks a connection, so the
  /// active screen can show the warning dialog.
  void Function({
    required String host,
    required int port,
    required String expectedFingerprint,
    required String presentedFingerprint,
  })? onHostKeyMismatch;

  Future<void> loadConfig() async {
    var profileData = await _config.getProfiles();
    final migratedProfiles =
        await SecureStorageService.migrateProfilePasswords(profileData);
    if (!identical(migratedProfiles, profileData)) {
      await _config.saveProfiles(migratedProfiles);
      profileData = migratedProfiles;
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
    if (securePassword == null || securePassword.isEmpty) {
      return profile;
    }
    return profile.copyWith(password: securePassword);
  }

  Future<void> saveProfile(SSHProfile profile) async {
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
    await _config.saveProfiles(profiles.map((e) => e.toJson()).toList());
    await WidgetProfileService.syncProfiles(profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((p) => p.id == id);
    await SecureStorageService.deleteProfilePassword(id);
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

    try {
      addLog('Connecting to ${profile.host}:${profile.port}...');
      final auth = await resolveSshAuthMaterial(profile);
      if (!auth.hasKeyAuth && !auth.hasPasswordAuth) {
        throw StateError(
          'No credentials: set a password or select an SSH key for this profile',
        );
      }

      final socket = await SSHSocket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 20),
      );
      final client = SSHClient(
        socket,
        username: profile.username,
        identities: auth.identities,
        onPasswordRequest: auth.hasPasswordAuth ? () => auth.password! : null,
        keepAliveInterval: const Duration(seconds: 15),
        onVerifyHostKey: (type, fingerprintBytes) async {
          final fingerprint = String.fromCharCodes(fingerprintBytes);
          final verifier = HostKeyVerificationService(_config);
          final stored = await verifier.loadHosts();
          final decision = verifier.evaluate(
            stored: stored,
            host: profile.host,
            port: profile.port,
            keyType: type,
            fingerprint: fingerprint,
          );
          switch (decision) {
            case HostKeyDecision.trusted:
              return true;
            case HostKeyDecision.mismatch:
              final expected = stored
                  .where((h) => h.matches(profile.host, profile.port))
                  .map((h) => h.fingerprint)
                  .join(', ');
              addLog(
                'Host key changed for ${profile.host}:${profile.port} — connection blocked',
              );
              onHostKeyMismatch?.call(
                host: profile.host,
                port: profile.port,
                expectedFingerprint: expected.isEmpty ? '(unknown)' : expected,
                presentedFingerprint: fingerprint,
              );
              return false;
            case HostKeyDecision.unknown:
              final prompt = KnownHostPrompt(
                host: profile.host,
                port: profile.port,
                keyType: type,
                fingerprint: fingerprint,
              );
              final hook = onVerifyHostKeyPrompt;
              final trusted = hook != null ? await hook(prompt) : true;
              if (trusted) {
                await verifier.trustHost(prompt);
                addLog(
                  'Trusted new host key for ${profile.host}:${profile.port} ($type $fingerprint)',
                );
                return true;
              }
              addLog(
                'Rejected unknown host key for ${profile.host}:${profile.port}',
              );
              return false;
          }
        },
      );

      final shell = await client.shell(
        pty: const SSHPtyConfig(width: 80, height: 24),
      );

      entry.client = client;
      entry.shellSession = shell;

      shell.stdout.listen((data) {
        entry.terminal.write(utf8.decode(data));
      });
      shell.stderr.listen((data) {
        entry.terminal.write(utf8.decode(data));
      });
      entry.terminal.onOutput = (data) {
        entry.touch();
        shell.stdin.add(utf8.encode(data));
      };

      entry.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        entry.shellSession
            ?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      unawaited(shell.done.then((_) async {
        addLog('Session ${entry.name} closed');
        if (AppLifecycleService.isInBackground) {
          entry.disconnectedWhileBackgrounded = true;
        }
        entry.isConnected = false;
        notifyListeners();
      }));

      entry.isConnected = true;
      entry.lastError = null;
      entry.shouldReconnectOnResume = true;
      entry.touch();
      addLog('Connected: ${entry.name}');
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
            addLog('Executed startup command via PowerShell wrapper: $psCmd');
          } catch (_) {
            shell.stdin.add(
              utf8.encode(
                withEnterSuffix(effectiveStartup, terminalEnterSends),
              ),
            );
            addLog('Fallback: Executed startup command raw: $effectiveStartup');
          }
        } else {
          shell.stdin.add(
            utf8.encode(
              withEnterSuffix(effectiveStartup, terminalEnterSends),
            ),
          );
          addLog('Executed startup command: $effectiveStartup');
        }
      }
    } catch (e) {
      addLog('Connection failed for ${profile.host}:${profile.port} — $e');
      entry.isConnected = false;
      entry.lastError = e.toString();
      entry.client = null;
      entry.shellSession = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reconnectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    entry.shellSession?.close();
    entry.client?.close();
    entry.shellSession = null;
    entry.client = null;
    // Preserve scrollback: reuse the existing Terminal buffer.
    entry.terminal.write('\r\n\x1b[90m--- reconnecting ---\x1b[0m\r\n');
    await connectSession(sessionId);
  }

  Future<void> disconnectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId,
        orElse: () => throw StateError('Session not found'));
    entry.shellSession?.close();
    entry.client?.close();
    entry.isConnected = false;
    entry.shouldReconnectOnResume = false;
    entry.disconnectedWhileBackgrounded = false;
    entry.terminal = Terminal();
    notifyListeners();
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

  String _getCtrlLabel(int charCode) {
    switch (charCode) {
      case 3:
        return 'C';
      case 4:
        return 'D';
      case 26:
        return 'Z';
      case 12:
        return 'L';
      case 1:
        return 'A';
      case 16:
        return 'P';
      default:
        return String.fromCharCode(charCode);
    }
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    connectionLog.add('[$timestamp] $message');
    if (connectionLog.length > 100) {
      connectionLog.removeAt(0);
    }
    notifyListeners();
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
    for (final s in sessions) {
      s.disposeRuntime();
    }
    super.dispose();
  }
}

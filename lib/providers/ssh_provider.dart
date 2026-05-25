import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/ssh_profile.dart';
import '../services/config_service.dart';
import '../services/network_discovery_service.dart';
import '../models/session_entry.dart';

class SSHProvider extends ChangeNotifier {
  // sessions container
  final List<SessionEntry> sessions = <SessionEntry>[];
  String? activeSessionId;

  bool isServerRunning = false;
  int serverPort = 22;
  String? serverAddress;
  List<String> connectionLog = [];

  List<SSHProfile> profiles = <SSHProfile>[];
  SSHProfile? lastSession;
  List<String> discoveredHosts = <String>[];
  bool isScanning = false;

  Future<void> loadConfig() async {
    final profileData = await ConfigService.getProfiles();
    profiles = profileData.map((e) => SSHProfile.fromJson(e)).toList();

    final sessionData = await ConfigService.getLastSession();
    if (sessionData != null) {
      lastSession = SSHProfile.fromJson(sessionData);
    }

    notifyListeners();
  }

  Future<void> saveProfile(SSHProfile profile) async {
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await ConfigService.saveProfiles(profiles.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((p) => p.id == id);
    await ConfigService.saveProfiles(profiles.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> saveLastSession(SSHProfile profile) async {
    lastSession = profile;
    await ConfigService.saveLastSession(profile.toJson());
    notifyListeners();
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

  Future<void> connectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId);
    final profile = entry.profile;

    try {
      addLog('Connecting to ${profile.host}:${profile.port}...');
      final socket = await SSHSocket.connect(profile.host, profile.port);
      final client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () => profile.password ?? '',
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
        shell.stdin.add(utf8.encode(data));
      };

      entry.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        entry.shellSession
            ?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      unawaited(shell.done.then((_) async {
        addLog('Session ${entry.name} closed');
        entry.isConnected = false;
        notifyListeners();
      }));

      entry.isConnected = true;
      addLog('Connected: ${entry.name}');
      notifyListeners();

      if (profile.startupCommand?.isNotEmpty ?? false) {
        final startupCommand = profile.startupCommand!;
        final trimmed = startupCommand.trim();
        final isGit = trimmed.toLowerCase().startsWith('git ');
        if (isGit) {
          final escaped = startupCommand.replaceAll("'", "''");
          const gitFullPath = r'C:\Program Files\Git\cmd\git.exe';
          final psCmd =
              "powershell -NoProfile -Command \"& '$gitFullPath' $escaped\"";
          try {
            shell.stdin.add(utf8.encode('$psCmd\r'));
            addLog('Executed startup command via PowerShell wrapper: $psCmd');
          } catch (_) {
            shell.stdin.add(utf8.encode('$startupCommand\r'));
            addLog('Fallback: Executed startup command raw: $startupCommand');
          }
        } else {
          shell.stdin.add(utf8.encode('$startupCommand\r'));
          addLog('Executed startup command: $startupCommand');
        }
      }
    } catch (e) {
      addLog('Connection failed for ${profile.host}:${profile.port} — $e');
      sessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnectSession(String sessionId) async {
    final entry = sessions.firstWhere((s) => s.id == sessionId,
        orElse: () => throw StateError('Session not found'));
    entry.shellSession?.close();
    entry.client?.close();
    entry.isConnected = false;
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

  Future<void> startServer({
    required int port,
    required String username,
    required String password,
    dynamic sshKeyType,
  }) async {
    try {
      serverPort = port;
      isServerRunning = true;

      final info = NetworkInfo();
      serverAddress = await info.getWifiIP();

      addLog('SSH Server running on ${serverAddress ?? '0.0.0.0'}:$port');
      notifyListeners();
    } catch (e) {
      addLog('Failed to start server: $e');
      isServerRunning = false;
      rethrow;
    }
  }

  void stopServer() {
    isServerRunning = false;
    addLog('Server stopped');
    notifyListeners();
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
      entry.shellSession!.stdin.add(utf8.encode(data));
    }
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

  @override
  void dispose() {
    for (final s in sessions) {
      s.disposeRuntime();
    }
    super.dispose();
  }
}

// lib/models/session_entry.dart
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import 'ssh_profile.dart';

class SessionEntry {
  final String id;
  final String name;
  final SSHProfile profile;

  // runtime fields (not serialized)
  SSHClient? client;
  SSHSession? shellSession;
  Terminal terminal;
  bool isConnected;
  bool disconnectedWhileBackgrounded;
  bool shouldReconnectOnResume;
  String? lastError;

  SessionEntry({
    required this.name,
    required this.profile,
    String? id,
    Terminal? terminal,
  })  : id = id ?? const Uuid().v4(),
        terminal = terminal ?? Terminal(),
        isConnected = false,
        disconnectedWhileBackgrounded = false,
        shouldReconnectOnResume = false,
        lastError = null;

  void disposeRuntime() {
    shellSession?.close();
    client?.close();
  }
}

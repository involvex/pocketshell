// lib/models/session_entry.dart
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_app/models/port_forward_rule.dart';
import 'package:ssh_app/services/ssh_local_forward.dart';
import 'ssh_profile.dart';

/// An active named local forward bound for a session.
class ActivePortForward {
  ActivePortForward({
    required this.rule,
    required this.forward,
  });

  final PortForwardRule rule;
  final SshLocalForward forward;
}

class SessionEntry {
  final String id;
  final String name;
  final SSHProfile profile;

  // runtime fields (not serialized)
  SSHClient? client;

  /// Bastion client when connecting via [SSHProfile.jumpProfileId].
  SSHClient? jumpClient;
  SSHSession? shellSession;
  Terminal terminal;
  bool isConnected;
  bool disconnectedWhileBackgrounded;
  bool shouldReconnectOnResume;

  /// When true, [shell.done] must not trigger foreground auto-reconnect
  /// (used while [SSHProvider.reconnectSession] closes the old shell).
  bool suppressAutoReconnect;

  /// Consecutive foreground reconnect attempts; reset on a successful connect.
  int reconnectAttempts;
  String? lastError;
  DateTime? lastActivityAt;
  final List<ActivePortForward> activeForwards = <ActivePortForward>[];

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
        suppressAutoReconnect = false,
        reconnectAttempts = 0,
        lastError = null;

  void touch() {
    lastActivityAt = DateTime.now();
  }

  Future<void> closeForwards() async {
    for (final active in List<ActivePortForward>.from(activeForwards)) {
      await active.forward.close();
    }
    activeForwards.clear();
  }

  void disposeRuntime() {
    // ignore: discarded_futures
    closeForwards();
    shellSession?.close();
    client?.close();
    jumpClient?.close();
  }
}

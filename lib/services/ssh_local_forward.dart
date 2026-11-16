import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// Dial callback used by [SshLocalForward] (defaults to [SSHClient.forwardLocal]).
typedef SshForwardDial = Future<SSHForwardChannel> Function(
  String remoteHost,
  int remotePort,
);

/// Listens on loopback and tunnels each accepted socket through SSH
/// `direct-tcpip` to a fixed remote host:port (agent OpenCode serve).
class SshLocalForward {
  SshLocalForward._({
    required ServerSocket server,
    required StreamSubscription<Socket> acceptSub,
  })  : _server = server,
        _acceptSub = acceptSub,
        localPort = server.port;

  final ServerSocket _server;
  final StreamSubscription<Socket> _acceptSub;
  final List<Socket> _localSockets = <Socket>[];
  final List<SSHForwardChannel> _channels = <SSHForwardChannel>[];
  bool _closed = false;

  /// Bound local TCP port on 127.0.0.1.
  final int localPort;

  /// Whether [close] has already been called.
  bool get isClosed => _closed;

  /// Binds `127.0.0.1:0` and forwards each connection to
  /// [remoteHost]:[remotePort] via [dial] (or [client.forwardLocal]).
  static Future<SshLocalForward> start({
    required SSHClient client,
    required int remotePort,
    String remoteHost = '127.0.0.1',
    SshForwardDial? dial,
  }) async {
    final SshForwardDial effectiveDial =
        dial ?? (host, port) => client.forwardLocal(host, port);
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    late final SshLocalForward forward;
    // Subscription lifetime is owned by [close].
    // ignore: cancel_subscriptions
    final acceptSub = server.listen(
      (Socket socket) {
        // ignore: unawaited_futures
        forward._handleClient(socket, effectiveDial, remoteHost, remotePort);
      },
      onError: (_) {},
      cancelOnError: false,
    );
    forward = SshLocalForward._(server: server, acceptSub: acceptSub);
    return forward;
  }

  /// Test helper: bind loopback only (no SSH dial). Accepted sockets are dropped.
  static Future<SshLocalForward> bindLoopbackForTest() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    late final SshLocalForward forward;
    // Subscription lifetime is owned by [close].
    // ignore: cancel_subscriptions
    final acceptSub = server.listen(
      (Socket socket) {
        forward._localSockets.add(socket);
        socket.destroy();
        forward._localSockets.remove(socket);
      },
      onError: (_) {},
      cancelOnError: false,
    );
    forward = SshLocalForward._(server: server, acceptSub: acceptSub);
    return forward;
  }

  Future<void> _handleClient(
    Socket socket,
    SshForwardDial dial,
    String remoteHost,
    int remotePort,
  ) async {
    if (_closed) {
      socket.destroy();
      return;
    }
    _localSockets.add(socket);
    SSHForwardChannel? channel;
    try {
      channel = await dial(remoteHost, remotePort);
      _channels.add(channel);
      socket.listen(
        (List<int> data) {
          channel?.sink.add(data);
        },
        onDone: () {
          // ignore: unawaited_futures
          channel?.close();
        },
        onError: (_) {
          channel?.destroy();
        },
        cancelOnError: true,
      );
      channel.stream.listen(
        (Uint8List data) {
          socket.add(data);
        },
        onDone: () {
          socket.destroy();
        },
        onError: (_) {
          socket.destroy();
        },
        cancelOnError: true,
      );
    } catch (_) {
      socket.destroy();
      // ignore: unawaited_futures
      channel?.close();
    }
  }

  /// Stops accepting connections and closes active sockets/channels.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _acceptSub.cancel();
    await _server.close();
    for (final socket in List<Socket>.from(_localSockets)) {
      socket.destroy();
    }
    _localSockets.clear();
    for (final channel in List<SSHForwardChannel>.from(_channels)) {
      channel.destroy();
    }
    _channels.clear();
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/ssh_local_forward.dart';

void main() {
  group('SshLocalForward', () {
    test('bindLoopbackForTest listens on 127.0.0.1 and close frees the port',
        () async {
      final forward = await SshLocalForward.bindLoopbackForTest();
      expect(forward.isClosed, isFalse);
      expect(forward.localPort, greaterThan(0));

      final probe = await Socket.connect(
        InternetAddress.loopbackIPv4,
        forward.localPort,
      );
      await probe.close();

      await forward.close();
      expect(forward.isClosed, isTrue);

      await forward.close(); // idempotent

      expect(
        () => Socket.connect(
          InternetAddress.loopbackIPv4,
          forward.localPort,
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}

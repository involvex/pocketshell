import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/port_forward_rule.dart';
import 'package:ssh_app/services/ssh_local_forward.dart';

void main() {
  group('PortForwardRule', () {
    test('tryParseLocalForward parses bind and remote', () {
      final rule = PortForwardRule.tryParseLocalForward(
        '3389 127.0.0.1:3389',
      );
      expect(rule, isNotNull);
      expect(rule!.localPort, 3389);
      expect(rule.remoteHost, '127.0.0.1');
      expect(rule.remotePort, 3389);
    });

    test('rdpPreset uses 3389', () {
      expect(PortForwardRule.rdpPreset.localPort, 3389);
      expect(PortForwardRule.rdpPreset.remotePort, 3389);
    });

    test('json round-trip', () {
      final rule = PortForwardRule(
        label: 'db',
        localPort: 5432,
        remoteHost: '127.0.0.1',
        remotePort: 5432,
      );
      final copy = PortForwardRule.fromJson(rule.toJson());
      expect(copy.localPort, 5432);
      expect(copy.label, 'db');
    });
  });

  group('SshLocalForward fixed port', () {
    test('bind conflict throws when port is taken', () async {
      final holder = await SshLocalForward.bindLoopbackForTest(localPort: 0);
      final taken = holder.localPort;
      await expectLater(
        SshLocalForward.bindLoopbackForTest(localPort: taken),
        throwsA(isA<SocketException>()),
      );
      await holder.close();
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/wake_on_lan_service.dart';

void main() {
  group('WakeOnLanService', () {
    test('parseMac accepts colon, dash, and bare hex', () {
      final a = WakeOnLanService.parseMac('AA:BB:CC:DD:EE:FF');
      final b = WakeOnLanService.parseMac('aa-bb-cc-dd-ee-ff');
      final c = WakeOnLanService.parseMac('AABBCCDDEEFF');
      expect(a, isNotNull);
      expect(b, equals(a));
      expect(c, equals(a));
      expect(WakeOnLanService.formatMac(a!), 'AA:BB:CC:DD:EE:FF');
    });

    test('parseMac rejects invalid lengths', () {
      expect(WakeOnLanService.parseMac('AA:BB'), isNull);
      expect(WakeOnLanService.parseMac(''), isNull);
    });

    test('buildMagicPacket is 102 bytes with FF header and 16 MAC copies', () {
      final mac = Uint8List.fromList(<int>[0x01, 0x02, 0x03, 0x04, 0x05, 0x06]);
      final packet = WakeOnLanService.buildMagicPacket(mac);
      expect(packet.length, 102);
      expect(packet.sublist(0, 6), everyElement(0xFF));
      for (var i = 0; i < 16; i++) {
        expect(
          packet.sublist(6 + i * 6, 12 + i * 6),
          equals(mac),
        );
      }
    });
  });
}

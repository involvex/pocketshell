import 'dart:io';
import 'dart:typed_data';

/// Builds and sends Wake-on-LAN magic packets.
class WakeOnLanService {
  const WakeOnLanService();

  /// Parses a MAC address in common forms (`AA:BB:…`, `AA-BB-…`, `AABBCC…`).
  ///
  /// Returns null when the value is not exactly 6 bytes.
  static Uint8List? parseMac(String raw) {
    final hex = raw.trim().replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hex.length != 12) {
      return null;
    }
    final bytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Formats [mac] as `AA:BB:CC:DD:EE:FF`.
  static String formatMac(Uint8List mac) {
    if (mac.length != 6) {
      throw ArgumentError.value(mac, 'mac', 'expected 6 bytes');
    }
    return mac
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Magic packet: 6× `0xFF` followed by the MAC repeated 16 times.
  static Uint8List buildMagicPacket(Uint8List mac) {
    if (mac.length != 6) {
      throw ArgumentError.value(mac, 'mac', 'expected 6 bytes');
    }
    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var i = 0; i < 16; i++) {
      packet.setRange(6 + i * 6, 12 + i * 6, mac);
    }
    return packet;
  }

  /// Sends a magic packet to [broadcastAddress] (default `255.255.255.255`)
  /// on UDP port 9.
  Future<void> sendMagicPacket({
    required String macAddress,
    String broadcastAddress = '255.255.255.255',
    int port = 9,
  }) async {
    final mac = parseMac(macAddress);
    if (mac == null) {
      throw FormatException('Invalid MAC address: $macAddress');
    }
    final packet = buildMagicPacket(mac);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final target = InternetAddress(broadcastAddress);
      final sent = socket.send(packet, target, port);
      if (sent == 0) {
        throw StateError('Failed to send Wake-on-LAN packet');
      }
    } finally {
      socket.close();
    }
  }
}

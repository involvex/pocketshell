import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// OpenSSH-style `SHA256:` fingerprint of a public key line or wire blob.
String sshPublicKeyFingerprint(String publicKeyLine) {
  final trimmed = publicKeyLine.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length < 2) {
    return _sha256Label(utf8.encode(trimmed));
  }
  try {
    final blob = base64Decode(parts[1]);
    return _sha256Label(blob);
  } catch (_) {
    return _sha256Label(utf8.encode(trimmed));
  }
}

String _sha256Label(List<int> bytes) {
  final digest = sha256.convert(bytes);
  final encoded = base64Encode(digest.bytes).replaceAll('=', '');
  return 'SHA256:$encoded';
}

/// Hex fingerprint of raw bytes (for tests / MAC display helpers).
String hexFingerprint(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
}

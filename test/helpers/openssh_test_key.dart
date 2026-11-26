import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Builds a disposable, unencrypted OpenSSH ed25519 private-key PEM in memory.
///
/// Used by unit tests so real key material is never committed to the repo
/// (GitGuardian / secret scanners).
Future<String> generateUnencryptedEd25519OpenSshPem() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final extracted = await keyPair.extract();
  final seed = Uint8List.fromList(extracted.bytes);
  final publicKey = Uint8List.fromList(extracted.publicKey.bytes);
  if (seed.length < 32 || publicKey.length != 32) {
    throw StateError('Unexpected ed25519 key lengths from cryptography');
  }

  final buffer = BytesBuilder();
  buffer.add(utf8.encode('openssh-key-v1\u0000'));
  _writeSshString(buffer, utf8.encode('none'));
  _writeSshString(buffer, utf8.encode('none'));
  _writeSshString(buffer, Uint8List(0));
  buffer.add(_uint32(1));

  final pubKeySsh = BytesBuilder();
  _writeSshString(pubKeySsh, utf8.encode('ssh-ed25519'));
  _writeSshString(pubKeySsh, publicKey);
  _writeSshString(buffer, pubKeySsh.toBytes());

  final check = Random.secure().nextInt(0xffffffff);
  final privSection = BytesBuilder();
  privSection.add(_uint32(check));
  privSection.add(_uint32(check));
  _writeSshString(privSection, utf8.encode('ssh-ed25519'));
  _writeSshString(privSection, publicKey);
  final combined = Uint8List(64);
  combined.setRange(0, 32, seed.sublist(0, 32));
  combined.setRange(32, 64, publicKey);
  _writeSshString(privSection, combined);
  _writeSshString(privSection, Uint8List(0));

  var privBytes = privSection.toBytes();
  final pad = 8 - (privBytes.length % 8);
  if (pad < 8) {
    final padded = Uint8List(privBytes.length + pad);
    padded.setRange(0, privBytes.length, privBytes);
    for (var i = 0; i < pad; i++) {
      padded[privBytes.length + i] = (i + 1) & 0xff;
    }
    privBytes = padded;
  }
  _writeSshString(buffer, privBytes);

  return _wrapPem('OPENSSH PRIVATE KEY', buffer.toBytes());
}

void _writeSshString(BytesBuilder buffer, List<int> data) {
  buffer.add(_uint32(data.length));
  buffer.add(data);
}

Uint8List _uint32(int value) {
  return Uint8List(4)
    ..[0] = (value >> 24) & 0xff
    ..[1] = (value >> 16) & 0xff
    ..[2] = (value >> 8) & 0xff
    ..[3] = value & 0xff;
}

String _wrapPem(String label, Uint8List bytes) {
  final b64 = base64Encode(bytes);
  final chunks = <String>[];
  for (var i = 0; i < b64.length; i += 64) {
    final end = (i + 64 < b64.length) ? i + 64 : b64.length;
    chunks.add(b64.substring(i, end));
  }
  return '-----BEGIN $label-----\n${chunks.join('\n')}\n-----END $label-----\n';
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Password-based encryption for backups (v2 envelope).
///
/// Scheme: PBKDF2-HMAC-SHA256 (600k iterations, 256-bit key) → AES-GCM-256.
/// Envelope JSON: `{version:2, kdf, iterations, salt, nonce, ciphertext}`.
/// Wrong passwords surface as [BackupCryptoException] without leaking metadata.
class BackupCryptoException implements Exception {
  const BackupCryptoException(this.message);
  final String message;
  @override
  String toString() => 'BackupCryptoException: $message';
}

class BackupCrypto {
  static const String kdfName = 'pbkdf2-sha256';
  static const int iterations = 600000;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Future<Map<String, dynamic>> encrypt(
    String plaintext,
    String password,
  ) async {
    if (password.isEmpty) {
      throw const BackupCryptoException('Password must not be empty');
    }
    final salt = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    final combined = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    return <String, dynamic>{
      'version': 2,
      'kdf': kdfName,
      'iterations': iterations,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(combined),
    };
  }

  static Future<String> decrypt(
    Map<String, dynamic> envelope,
    String password,
  ) async {
    try {
      final version = envelope['version'] as int?;
      if (version != 2) {
        throw const BackupCryptoException('Unsupported backup version');
      }
      if (envelope['kdf'] != kdfName) {
        throw const BackupCryptoException('Unsupported key derivation');
      }
      final iters = envelope['iterations'] as int? ?? 0;
      if (iters <= 0 || iters > 2000000) {
        throw const BackupCryptoException('Invalid iteration count');
      }
      final salt = base64.decode(envelope['salt'] as String);
      final nonce = base64.decode(envelope['nonce'] as String);
      final combined = base64.decode(envelope['ciphertext'] as String);
      if (combined.length < 17) {
        throw const BackupCryptoException('Backup data is truncated');
      }
      final cipherText =
          Uint8List.fromList(combined.sublist(0, combined.length - 16));
      final macBytes =
          Uint8List.fromList(combined.sublist(combined.length - 16));
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iters,
        bits: 256,
      );
      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final aes = AesGcm.with256bits();
      final box = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clear = await aes.decrypt(box, secretKey: secretKey);
      return utf8.decode(clear);
    } on BackupCryptoException {
      rethrow;
    } catch (_) {
      throw const BackupCryptoException(
        'Wrong password or corrupted backup',
      );
    }
  }
}

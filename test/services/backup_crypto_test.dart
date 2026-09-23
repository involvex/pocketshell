import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/backup_crypto.dart';

void main() {
  test('encrypt/decrypt round-trips', () async {
    const plaintext = '{"version":1,"profiles":[]}';
    final envelope = await BackupCrypto.encrypt(plaintext, 'correct-horse-123');
    expect(envelope['version'], 2);
    final restored = await BackupCrypto.decrypt(
      envelope,
      'correct-horse-123',
    );
    expect(restored, plaintext);
  });

  test('wrong password throws without leaking plaintext', () async {
    final envelope = await BackupCrypto.encrypt('secret', 'right-password');
    expect(
      () => BackupCrypto.decrypt(envelope, 'wrong-password'),
      throwsA(isA<BackupCryptoException>()),
    );
    expect(envelope.toString(), isNot(contains('secret')));
  });

  test('empty password is rejected', () async {
    expect(
      () => BackupCrypto.encrypt('x', ''),
      throwsA(isA<BackupCryptoException>()),
    );
  });
}

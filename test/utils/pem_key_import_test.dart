import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_key.dart';
import 'package:ssh_app/utils/pem_key_import.dart';

import '../helpers/openssh_test_key.dart';

void main() {
  group('tryImportUnencryptedPemKey', () {
    test('imports an unencrypted OpenSSH ed25519 PEM', () async {
      final pem = await generateUnencryptedEd25519OpenSshPem();

      final result = tryImportUnencryptedPemKey(pem, name: 'imported');

      expect(result.isOk, isTrue);
      expect(result.key!.name, 'imported');
      expect(result.key!.keyType, SSHKeyType.ed25519);
      expect(result.key!.publicKey, startsWith('ssh-ed25519 '));
      expect(result.key!.privateKey, contains('BEGIN'));
    });

    test('rejects non-PEM text', () {
      final result = tryImportUnencryptedPemKey(
        'not-a-key',
        name: 'x',
      );
      expect(result.failure, PemKeyImportFailure.notPem);
    });

    test('rejects garbage PEM that looks encrypted-shaped', () {
      const junk = '''
-----BEGIN OPENSSH PRIVATE KEY-----
bm90LWEtcmVhbC1rZXk=
-----END OPENSSH PRIVATE KEY-----
''';
      final result = tryImportUnencryptedPemKey(junk, name: 'x');
      expect(result.isOk, isFalse);
      expect(
        result.failure,
        anyOf(
          PemKeyImportFailure.parseFailed,
          PemKeyImportFailure.encrypted,
          PemKeyImportFailure.unsupportedType,
        ),
      );
    });
  });

  group('sshKeyTypeForAlgorithm', () {
    test('maps known algorithms', () {
      expect(sshKeyTypeForAlgorithm('ssh-ed25519'), SSHKeyType.ed25519);
      expect(sshKeyTypeForAlgorithm('ssh-rsa'), SSHKeyType.rsa2048);
      expect(sshKeyTypeForAlgorithm('ecdsa-sha2-nistp256'), SSHKeyType.ecdsa256);
      expect(sshKeyTypeForAlgorithm('unknown'), isNull);
    });
  });
}

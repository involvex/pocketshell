import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_app/utils/ssh_auth_utils.dart';

void main() {
  group('looksLikePemPrivateKey', () {
    test('detects PEM blobs', () {
      expect(
        looksLikePemPrivateKey(
          '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
        ),
        isTrue,
      );
    });

    test('rejects key ids', () {
      expect(looksLikePemPrivateKey('uuid-key-id'), isFalse);
    });
  });
}

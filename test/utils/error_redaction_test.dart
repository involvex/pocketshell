import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/error_redaction.dart';

void main() {
  group('redactErrorForDisplay', () {
    test('redacts Basic auth payloads', () {
      expect(
        redactErrorForDisplay('401 Authorization: Basic dXNlcjpzZWNyZXQ='),
        contains('Basic ***'),
      );
      expect(
        redactErrorForDisplay('401 Authorization: Basic dXNlcjpzZWNyZXQ='),
        isNot(contains('dXNlcjpzZWNyZXQ=')),
      );
    });

    test('redacts password fields and PEM', () {
      const pem = '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET\n'
          '-----END OPENSSH PRIVATE KEY-----';
      final redacted = redactErrorForDisplay(
        'auth failed password=hunter2 key=$pem',
      );
      expect(redacted, contains('password=***'));
      expect(redacted, contains('REDACTED'));
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('SECRET')));
    });
  });
}

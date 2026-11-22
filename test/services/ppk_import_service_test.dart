import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/ppk_import_service.dart';

void main() {
  group('PpkImportService', () {
    test('looksLikePpk detects headers', () {
      expect(
        PpkImportService.looksLikePpk('PuTTY-User-Key-File-2: ssh-ed25519\n'),
        isTrue,
      );
      expect(
        PpkImportService.looksLikePpk('PuTTY-User-Key-File-3: ssh-rsa\n'),
        isTrue,
      );
      expect(PpkImportService.looksLikePpk('-----BEGIN'), isFalse);
    });

    test('rejects empty file', () async {
      await expectLater(
        const PpkImportService().importPpk(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects encrypted PPK without passphrase', () async {
      const encrypted = '''
PuTTY-User-Key-File-2: ssh-ed25519
Encryption: aes256-cbc
Comment: test
Public-Lines: 1
AAAA
Private-Lines: 1
BBBB
Private-MAC: 00
''';
      await expectLater(
        const PpkImportService().importPpk(encrypted),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('passphrase'),
          ),
        ),
      );
    });
  });
}

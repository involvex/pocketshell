import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/sftp_mode_utils.dart';

void main() {
  group('sftp_mode_utils', () {
    test('parseSftpOctalMode accepts 644 and 0755', () {
      expect(parseSftpOctalMode('644'), 420);
      expect(parseSftpOctalMode('0755'), 493);
    });

    test('setSftpModePermission toggles owner read', () {
      const int mode = 33152; // 0o100600
      final int withRead = setSftpModePermission(mode, 0, true);
      expect(sftpModeHasPermission(withRead, 0), isTrue);
      final int withoutRead = setSftpModePermission(withRead, 0, false);
      expect(sftpModeHasPermission(withoutRead, 0), isFalse);
    });

    test('formatSftpPermissionOctal prints three digits', () {
      expect(formatSftpPermissionOctal(33188), '644');
    });
  });
}
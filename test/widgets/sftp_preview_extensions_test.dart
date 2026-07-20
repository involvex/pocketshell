import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/widgets/sftp/sftp_image_preview.dart';
import 'package:ssh_app/widgets/sftp/sftp_text_preview.dart';

void main() {
  group('isSftpTextPreviewExtension', () {
    test('accepts supported text extensions case-insensitively', () {
      expect(isSftpTextPreviewExtension('notes.TXT'), isTrue);
      expect(isSftpTextPreviewExtension('config.YmL'), isTrue);
      expect(isSftpTextPreviewExtension('.env'), isTrue);
    });

    test('rejects unsupported or missing extensions', () {
      expect(isSftpTextPreviewExtension('archive.zip'), isFalse);
      expect(isSftpTextPreviewExtension('README'), isFalse);
    });
  });

  group('isSftpImagePreviewExtension', () {
    test('accepts supported image extensions case-insensitively', () {
      expect(isSftpImagePreviewExtension('photo.JPEG'), isTrue);
      expect(isSftpImagePreviewExtension('preview.WebP'), isTrue);
    });

    test('rejects unsupported image extensions', () {
      expect(isSftpImagePreviewExtension('diagram.svg'), isFalse);
      expect(isSftpImagePreviewExtension('image'), isFalse);
    });
  });
}

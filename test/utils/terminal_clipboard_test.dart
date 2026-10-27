import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/terminal_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalClipboard', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '  keep spaces  '};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('readText preserves whitespace (no trim)', () async {
      final text = await TerminalClipboard.readText();
      expect(text, '  keep spaces  ');
    });

    test('copyText completes', () async {
      await TerminalClipboard.copyText('hello');
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/terminal_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalClipboard', () {
    String? lastSetText;

    setUp(() {
      lastSetText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final Object? args = call.arguments;
          if (args is Map) {
            lastSetText = args['text'] as String?;
          }
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': lastSetText ?? '  keep spaces  '};
        }
        if (call.method == 'Clipboard.hasStrings') {
          return <String, dynamic>{
            'value': lastSetText != null && lastSetText!.isNotEmpty,
          };
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

    test('copyText completes and returns true', () async {
      final bool ok = await TerminalClipboard.copyText('hello');
      expect(ok, isTrue);
      expect(lastSetText, 'hello');
    });

    test('sanitize strips NULs and lone CR', () {
      expect(TerminalClipboard.sanitize('a\u0000b'), 'ab');
      expect(TerminalClipboard.sanitize('a\rb'), 'a\nb');
      expect(TerminalClipboard.sanitize('a\r\nb'), 'a\nb');
    });
  });
}

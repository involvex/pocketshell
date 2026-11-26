import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/widgets/keyboard_shortcut_bar.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('shortcutActionSupportsKeyRepeat', () {
    test('arrows repeat; other actions do not', () {
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.arrowLeft), isTrue);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.arrowRight), isTrue);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.arrowUp), isTrue);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.arrowDown), isTrue);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.home), isFalse);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.ctrlC), isFalse);
      expect(shortcutActionSupportsKeyRepeat(ShortcutAction.tabChar), isFalse);
    });
  });

  group('terminalKeyForShortcutAction', () {
    test('maps arrow actions to TerminalKey', () {
      expect(
        terminalKeyForShortcutAction(ShortcutAction.arrowLeft),
        TerminalKey.arrowLeft,
      );
      expect(
        terminalKeyForShortcutAction(ShortcutAction.arrowRight),
        TerminalKey.arrowRight,
      );
      expect(terminalKeyForShortcutAction(ShortcutAction.ctrlC), isNull);
    });
  });
}

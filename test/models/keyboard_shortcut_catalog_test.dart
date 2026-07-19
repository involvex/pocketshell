import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';

void main() {
  group('KeyboardShortcut action catalog', () {
    test('createForAction fills ctrl defaults', () {
      final KeyboardShortcut shortcut = KeyboardShortcut.createForAction(
        ShortcutAction.ctrlD,
        row: 2,
      );

      expect(shortcut.label, 'Ctrl+D');
      expect(shortcut.description, 'EOF');
      expect(shortcut.action, ShortcutAction.ctrlD);
      expect(shortcut.charCode, 4);
      expect(shortcut.row, 2);
      expect(shortcut.id, isNotEmpty);
    });

    test('actionsForRow returns row-appropriate actions', () {
      expect(
        KeyboardShortcut.actionsForRow(0),
        containsAll(<ShortcutAction>[
          ShortcutAction.newConnection,
          ShortcutAction.profiles,
          ShortcutAction.discovery,
          ShortcutAction.keys,
        ]),
      );
      expect(
        KeyboardShortcut.actionsForRow(2),
        contains(ShortcutAction.ctrlC),
      );
      expect(
        KeyboardShortcut.actionsForRow(2),
        isNot(contains(ShortcutAction.newConnection)),
      );
    });

    test('defaultCharCodeFor returns null for non-control actions', () {
      expect(
        KeyboardShortcut.defaultCharCodeFor(ShortcutAction.profiles),
        isNull,
      );
      expect(
        KeyboardShortcut.defaultCharCodeFor(ShortcutAction.ctrlV),
        isNull,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_selection.dart';
import 'package:ssh_app/utils/terminal_selection_range.dart';

void main() {
  group('exclusiveEndFromDrag', () {
    test('adds one column when dragging forward on same line', () {
      expect(
        exclusiveEndFromDrag(
          from: const CellOffset(2, 0),
          to: const CellOffset(5, 0),
        ),
        const CellOffset(6, 0),
      );
    });

    test('adds one column when to.x equals from.x', () {
      expect(
        exclusiveEndFromDrag(
          from: const CellOffset(3, 0),
          to: const CellOffset(3, 0),
        ),
        const CellOffset(4, 0),
      );
    });

    test('does not add when dragging to a smaller x', () {
      expect(
        exclusiveEndFromDrag(
          from: const CellOffset(5, 0),
          to: const CellOffset(2, 0),
        ),
        const CellOffset(2, 0),
      );
    });
  });

  group('extentHandleCell', () {
    test('sits on last included cell for exclusive end', () {
      final BufferRange range = BufferRangeLine(
        const CellOffset(0, 0),
        const CellOffset(5, 0),
      );
      expect(extentHandleCell(range), const CellOffset(4, 0));
    });

    test('collapsed selection uses begin', () {
      final BufferRange range = BufferRangeLine.collapsed(
        const CellOffset(3, 1),
      );
      expect(extentHandleCell(range), const CellOffset(3, 1));
    });
  });

  group('setCharacterSelection', () {
    test('copies inclusive finger cell via exclusive end', () {
      final Terminal terminal = Terminal(maxLines: 100);
      terminal.write('hello world\r\n');
      final TerminalController controller = TerminalController();

      setCharacterSelection(
        terminal: terminal,
        controller: controller,
        begin: const CellOffset(0, 0),
        extentFinger: const CellOffset(4, 0),
      );

      expect(selectedTerminalText(terminal, controller), 'hello');
    });
  });
}

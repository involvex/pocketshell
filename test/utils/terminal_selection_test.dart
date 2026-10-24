import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_selection.dart';

void main() {
  test('selectedTerminalText returns buffer text for active selection', () {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello world\r\n');
    final TerminalController controller = TerminalController();
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );

    expect(selectedTerminalText(terminal, controller), contains('hello'));
  });

  test('selectedTerminalText is null when selection cleared', () {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello\r\n');
    final TerminalController controller = TerminalController();

    expect(selectedTerminalText(terminal, controller), isNull);
  });
}

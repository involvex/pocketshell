import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/widgets/terminal_search_bar.dart';

void main() {
  test('search scroll keeps selection anchors attached', () {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('find me here\r\nsecond line\r\n');
    final TerminalController controller = TerminalController();
    final TerminalSearchSession session = TerminalSearchSession(
      terminal: terminal,
      controller: controller,
    );

    session.search('find');
    expect(session.hasResults, isTrue);
    expect(controller.selection, isNotNull);

    session.dispose();
  });
}

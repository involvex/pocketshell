import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_search.dart';

Terminal _terminalWithOutput(String text) {
  final Terminal terminal = Terminal();
  terminal.write(text);
  return terminal;
}

void main() {
  group('findTerminalMatches', () {
    test('finds matches with line and column info', () {
      final Terminal terminal = _terminalWithOutput(
        'hello world\r\nfoo bar\r\nsay hello again\r\n',
      );

      final List<TerminalSearchMatch> matches =
          findTerminalMatches(terminal, 'hello');

      expect(matches, hasLength(2));
      expect(matches[0].line, 0);
      expect(matches[0].startX, 0);
      expect(matches[0].endX, 5);
      expect(matches[1].line, 2);
      expect(matches[1].startX, 4);
      expect(matches[1].endX, 9);
    });

    test('is case-insensitive by default', () {
      final Terminal terminal = _terminalWithOutput('Hello HELLO\r\n');

      expect(findTerminalMatches(terminal, 'hello'), hasLength(2));
      expect(
        findTerminalMatches(terminal, 'hello', caseSensitive: true),
        isEmpty,
      );
      expect(
        findTerminalMatches(terminal, 'HELLO', caseSensitive: true),
        hasLength(1),
      );
    });

    test('empty query returns no matches', () {
      final Terminal terminal = _terminalWithOutput('some output\r\n');
      expect(findTerminalMatches(terminal, ''), isEmpty);
    });

    test('no hits returns empty list', () {
      final Terminal terminal = _terminalWithOutput('some output\r\n');
      expect(findTerminalMatches(terminal, 'zzz'), isEmpty);
    });

    test('respects maxMatches cap', () {
      final Terminal terminal = _terminalWithOutput('a a a a a a a a a a\r\n');
      final List<TerminalSearchMatch> matches =
          findTerminalMatches(terminal, 'a', maxMatches: 3);
      expect(matches, hasLength(3));
    });
  });
}

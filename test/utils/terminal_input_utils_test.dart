import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/session_manager.dart';
import 'package:ssh_app/utils/terminal_enter_mapping.dart';

void main() {
  group('enterSequenceFor', () {
    test('maps CR and Ctrl+M to carriage return', () {
      expect(enterSequenceFor(TerminalEnterSends.cr), '\r');
      expect(enterSequenceFor(TerminalEnterSends.ctrlM), '\r');
    });

    test('maps LF and CRLF', () {
      expect(enterSequenceFor(TerminalEnterSends.lf), '\n');
      expect(enterSequenceFor(TerminalEnterSends.crlf), '\r\n');
    });
  });

  group('normalizeNewlines', () {
    test('rewrites mixed newlines to configured sequence', () {
      const input = 'a\r\nb\rc\nd';
      expect(
        normalizeNewlines(input, TerminalEnterSends.crlf),
        'a\r\nb\r\nc\r\nd',
      );
      expect(
        normalizeNewlines(input, TerminalEnterSends.lf),
        'a\nb\nc\nd',
      );
      expect(
        normalizeNewlines(input, TerminalEnterSends.cr),
        'a\rb\rc\rd',
      );
    });
  });

  group('withEnterSuffix', () {
    test('appends enter sequence', () {
      expect(withEnterSuffix('ls', TerminalEnterSends.cr), 'ls\r');
      expect(withEnterSuffix('ls', TerminalEnterSends.crlf), 'ls\r\n');
    });
  });

  group('resolveStartupCommand', () {
    test('prefers explicit startup command over session manager', () {
      expect(
        resolveStartupCommand(
          sessionManager: SessionManager.tmux,
          startupCommand: 'echo hi',
        ),
        'echo hi',
      );
    });

    test('uses session manager when startup is empty', () {
      expect(
        resolveStartupCommand(
          sessionManager: SessionManager.tmux,
          startupCommand: null,
        ),
        SessionManager.tmux.attachOrNewCommand,
      );
      expect(
        resolveStartupCommand(
          sessionManager: SessionManager.none,
          startupCommand: '  ',
        ),
        isNull,
      );
    });

    test('psmux provides a windows-oriented command', () {
      final cmd = SessionManager.psmux.attachOrNewCommand;
      expect(cmd, isNotNull);
      expect(cmd, contains('psmux'));
    });
  });
}

import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_clipboard.dart';

/// Returns the plain text for the controller's current selection, if any.
String? selectedTerminalText(Terminal terminal, TerminalController controller) {
  final BufferRange? selection = controller.selection;
  if (selection == null) {
    return null;
  }
  final String text =
      TerminalClipboard.sanitize(terminal.buffer.getText(selection));
  if (text.isEmpty) {
    return null;
  }
  return text;
}

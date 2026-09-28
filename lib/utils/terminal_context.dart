import 'dart:math';

import 'package:xterm/xterm.dart';

const int kDefaultTerminalContextLines = 30;

String extractRecentTerminalOutput(
  Terminal terminal, {
  int lineCount = kDefaultTerminalContextLines,
}) {
  final buffer = terminal.buffer;
  final height = buffer.height;
  if (height == 0) {
    return '';
  }

  final startLine = max(0, height - lineCount);
  final text = buffer.getText(
    BufferRangeLine(
      CellOffset(0, startLine),
      CellOffset(buffer.viewWidth - 1, height - 1),
    ),
  );
  return text.trim();
}

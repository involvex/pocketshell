import 'package:xterm/xterm.dart';

/// A single search hit in the terminal scrollback buffer.
class TerminalSearchMatch {
  const TerminalSearchMatch({
    required this.line,
    required this.startX,
    required this.endX,
  });

  /// Absolute buffer line index (includes scrollback).
  final int line;

  /// Inclusive start cell column.
  final int startX;

  /// Exclusive end cell column.
  final int endX;
}

/// Scans the whole buffer (including scrollback) for [query], oldest line
/// first. Returns at most [maxMatches] hits.
///
/// Cell columns are mapped precisely by walking cells and skipping empty
/// ones, so gaps or wide characters don't shift the highlight.
List<TerminalSearchMatch> findTerminalMatches(
  Terminal terminal,
  String query, {
  bool caseSensitive = false,
  int maxMatches = 500,
}) {
  if (query.isEmpty) {
    return const <TerminalSearchMatch>[];
  }
  final String needle = caseSensitive ? query : query.toLowerCase();
  final Buffer buffer = terminal.buffer;
  final List<TerminalSearchMatch> matches = <TerminalSearchMatch>[];
  for (var y = 0; y < buffer.height; y++) {
    final BufferLine line = buffer.lines[y];
    final StringBuffer text = StringBuffer();
    final List<int> cellForTextIndex = <int>[];
    for (var x = 0; x < line.length; x++) {
      final int codePoint = line.getCodePoint(x);
      if (codePoint == 0) {
        continue;
      }
      text.writeCharCode(codePoint);
      cellForTextIndex.add(x);
    }
    if (cellForTextIndex.isEmpty) {
      continue;
    }
    final String haystack =
        caseSensitive ? text.toString() : text.toString().toLowerCase();
    var from = 0;
    while (true) {
      final int hit = haystack.indexOf(needle, from);
      if (hit < 0) {
        break;
      }
      final int startCell = cellForTextIndex[hit];
      final int lastCharCell = cellForTextIndex[hit + needle.length - 1];
      final int endCell = lastCharCell + line.getWidth(lastCharCell);
      matches.add(
        TerminalSearchMatch(line: y, startX: startCell, endX: endCell),
      );
      if (matches.length >= maxMatches) {
        return matches;
      }
      from = hit + needle.length;
    }
  }
  return matches;
}

/// How the Enter key (and normalized newlines) are sent to the remote PTY.
enum TerminalEnterSends {
  cr,
  lf,
  crlf,
  ctrlM,
}

/// Returns the byte sequence for a single Enter / newline under [mapping].
///
/// CR and Ctrl+M both produce ASCII 13 (`\r`).
String enterSequenceFor(TerminalEnterSends mapping) {
  return switch (mapping) {
    TerminalEnterSends.cr || TerminalEnterSends.ctrlM => '\r',
    TerminalEnterSends.lf => '\n',
    TerminalEnterSends.crlf => '\r\n',
  };
}

/// Rewrites `\r\n`, `\r`, and `\n` in [text] to the configured enter sequence.
String normalizeNewlines(String text, TerminalEnterSends mapping) {
  final replacement = enterSequenceFor(mapping);
  return text
      .replaceAll('\r\n', '\u0000')
      .replaceAll('\r', '\u0000')
      .replaceAll('\n', '\u0000')
      .replaceAll('\u0000', replacement);
}

/// Appends the enter sequence for [mapping] to [command].
String withEnterSuffix(String command, TerminalEnterSends mapping) {
  return '$command${enterSequenceFor(mapping)}';
}

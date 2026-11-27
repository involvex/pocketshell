/// Log-safe summary of a remote startup command (no full argv/secrets).
String redactStartupCommandLog(String command) {
  final trimmed = command.trim();
  if (trimmed.isEmpty) {
    return '(empty)';
  }
  final first = trimmed.split(RegExp(r'\s+')).first;
  return '$first … (${trimmed.length} chars)';
}

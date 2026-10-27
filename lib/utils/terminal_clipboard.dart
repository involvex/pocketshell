import 'package:flutter/services.dart';

/// Shared clipboard helpers for terminal copy/paste.
///
/// Always uses [Clipboard.kTextPlain] and never trims paste content so
/// intentional leading/trailing whitespace in commands is preserved.
class TerminalClipboard {
  const TerminalClipboard._();

  /// Copies [text] to the system clipboard.
  static Future<void> copyText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Reads plain text from the clipboard, or `null` when empty/unavailable.
  static Future<String?> readText() async {
    final ClipboardData? data =
        await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

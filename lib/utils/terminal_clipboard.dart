import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shared clipboard helpers for terminal copy/paste.
///
/// Always uses [Clipboard.kTextPlain] and never trims paste content so
/// intentional leading/trailing whitespace in commands is preserved.
///
/// On Android, writes go through a native channel that mirrors an EditText
/// "Copy" so Gboard clipboard history records the clip (system clipboard /
/// Phone Link already worked with a plain [ClipboardManager] write alone).
class TerminalClipboard {
  const TerminalClipboard._();

  static const MethodChannel _androidChannel =
      MethodChannel('com.involvex.ssh_app/clipboard');

  /// Strips NULs and normalizes lone CR that confuse Android clipboards.
  static String sanitize(String text) {
    if (text.isEmpty) {
      return text;
    }
    final StringBuffer out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final int code = text.codeUnitAt(i);
      if (code == 0) {
        continue;
      }
      if (code == 0x0d) {
        final bool nextIsLf =
            i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0a;
        if (!nextIsLf) {
          out.writeCharCode(0x0a);
        }
        continue;
      }
      out.writeCharCode(code);
    }
    return out.toString();
  }

  /// Copies [text] to the system clipboard.
  ///
  /// Returns `true` when the write appears to have succeeded.
  static Future<bool> copyText(String text) async {
    final String sanitized = sanitize(text);
    if (sanitized.isEmpty) {
      return false;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final Object? ok = await _androidChannel.invokeMethod<Object?>(
          'setClipboardText',
          <String, dynamic>{'text': sanitized},
        );
        // Also hit Flutter's path so any engine-side listeners fire.
        await Clipboard.setData(ClipboardData(text: sanitized));
        if (ok == true) {
          return true;
        }
      } on MissingPluginException {
        // Fall through to Flutter clipboard (tests / older builds).
      } on PlatformException {
        // Fall through.
      }
    }

    await Clipboard.setData(ClipboardData(text: sanitized));
    try {
      final bool has = await Clipboard.hasStrings();
      if (has) {
        return true;
      }
    } on Object {
      // hasStrings unavailable — assume setData worked.
    }
    return true;
  }

  /// Reads plain text from the clipboard, or `null` when empty/unavailable.
  static Future<String?> readText() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final Object? raw = await _androidChannel.invokeMethod<Object?>(
          'getClipboardText',
        );
        if (raw is String && raw.isNotEmpty) {
          return raw;
        }
        if (raw == null) {
          return null;
        }
      } on MissingPluginException {
        // Fall through.
      } on PlatformException {
        // Fall through.
      }
    }

    final ClipboardData? data =
        await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

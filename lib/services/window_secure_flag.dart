import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reference-counted Android `FLAG_SECURE` so Recents/screenshots hide
/// sensitive UI (app lock, private-key reveal).
class WindowSecureFlag {
  WindowSecureFlag._();

  static const MethodChannel _channel =
      MethodChannel('com.involvex.ssh_app/window');

  static int _holds = 0;

  static Future<void> acquire() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _holds++;
    if (_holds == 1) {
      try {
        await _channel.invokeMethod<void>('setSecureFlag', true);
      } on PlatformException {
        _holds--;
      }
    }
  }

  static Future<void> release() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    if (_holds == 0) {
      return;
    }
    _holds--;
    if (_holds == 0) {
      try {
        await _channel.invokeMethod<void>('setSecureFlag', false);
      } on PlatformException {
        // Ignore; flag may already be clear.
      }
    }
  }
}

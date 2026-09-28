import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Starts/stops the Android foreground service that keeps connections alive.
class ConnectionForegroundService {
  ConnectionForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.involvex.ssh_app/connection_service');

  static int _lastCount = 0;

  static Future<void> syncActiveConnections(int count) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (count == _lastCount) return;
    _lastCount = count;

    try {
      if (count > 0) {
        await _channel.invokeMethod<void>(
          'startForegroundService',
          <String, dynamic>{'connectionCount': count},
        );
      } else {
        await _channel.invokeMethod<void>('stopForegroundService');
      }
    } on PlatformException {
      // Native layer unavailable in tests or unsupported builds.
    }
  }
}

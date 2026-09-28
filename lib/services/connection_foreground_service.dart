import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'config_service.dart';

/// Starts/stops the Android foreground service that keeps connections alive.
class ConnectionForegroundService {
  ConnectionForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.involvex.ssh_app/connection_service');

  /// Storage key for the notification priority preference. Public so
  /// [applyNotificationPriority] and settings stay in sync.
  static const String prioritySettingKey = 'prominentConnectionNotification';

  static int _lastCount = 0;

  static Future<void> syncActiveConnections(int count) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (count == _lastCount) return;
    _lastCount = count;

    try {
      if (count > 0) {
        final settings = await ConfigService.getSettings();
        final prominent = settings[prioritySettingKey] as bool? ?? false;
        await _channel.invokeMethod<void>(
          'startForegroundService',
          <String, dynamic>{
            'connectionCount': count,
            'prominent': prominent,
          },
        );
      } else {
        await _channel.invokeMethod<void>('stopForegroundService');
      }
    } on PlatformException {
      // Native layer unavailable in tests or unsupported builds.
    }
  }

  /// Applies a new notification priority live while the service runs.
  /// No-op when no connections are active; the preference is picked up on
  /// the next [syncActiveConnections] with a changed count.
  static Future<void> applyNotificationPriority(bool prominent) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_lastCount <= 0) return;
    try {
      await _channel.invokeMethod<void>(
        'setNotificationPriority',
        <String, dynamic>{'prominent': prominent},
      );
    } on PlatformException {
      // Native layer unavailable in tests or unsupported builds.
    }
  }
}

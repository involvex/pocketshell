import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ssh_app/services/config_repository.dart';

/// Opt-in biometric / device-credential lock for the home UI.
///
/// SSH and agent sessions stay alive while locked; only the UI is covered.
class AppLockProvider extends ChangeNotifier {
  AppLockProvider({
    ConfigRepository? config,
    LocalAuthentication? localAuth,
  })  : _config = config ?? ConfigServiceRepository(),
        _localAuth = localAuth ?? LocalAuthentication();

  final ConfigRepository _config;
  final LocalAuthentication _localAuth;

  bool _enabled = false;
  int _autoLockMinutes = 5;
  bool _locked = false;
  bool _loaded = false;
  DateTime? _backgroundedAt;

  bool get isLoaded => _loaded;
  bool get enabled => _enabled;
  int get autoLockMinutes => _autoLockMinutes;
  bool get isLocked => _locked && _enabled;

  Future<void> load() async {
    final settings = await _config.getSettings();
    _enabled = settings['appLockEnabled'] as bool? ?? false;
    _autoLockMinutes =
        (settings['appLockAutoLockMinutes'] as num?)?.toInt() ?? 5;
    if (_autoLockMinutes != 1 &&
        _autoLockMinutes != 5 &&
        _autoLockMinutes != 15) {
      _autoLockMinutes = 5;
    }
    _loaded = true;
    if (_enabled) {
      _locked = true;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _save('appLockEnabled', value);
    if (value) {
      _locked = true;
    } else {
      _locked = false;
    }
    notifyListeners();
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (minutes != 1 && minutes != 5 && minutes != 15) {
      return;
    }
    _autoLockMinutes = minutes;
    await _save('appLockAutoLockMinutes', minutes);
    notifyListeners();
  }

  void lockNow() {
    if (!_enabled) {
      return;
    }
    _locked = true;
    notifyListeners();
  }

  void onAppPaused() {
    _backgroundedAt ??= DateTime.now();
  }

  void onAppResumed() {
    final backgrounded = _backgroundedAt;
    _backgroundedAt = null;
    if (!_enabled || backgrounded == null) {
      return;
    }
    final elapsed = DateTime.now().difference(backgrounded);
    if (elapsed >= Duration(minutes: _autoLockMinutes)) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<bool> unlock() async {
    if (!_enabled) {
      _locked = false;
      notifyListeners();
      return true;
    }
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock PocketShell',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save(String key, dynamic value) async {
    final settings = await _config.getSettings();
    settings[key] = value;
    await _config.saveSettings(settings);
  }
}

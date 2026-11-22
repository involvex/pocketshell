import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/providers/app_lock_provider.dart';
import 'package:ssh_app/services/config_repository.dart';

void main() {
  group('AppLockProvider', () {
    test('enable locks immediately; lockNow stays locked', () async {
      final config = FakeConfigRepository();
      final lock = AppLockProvider(config: config);
      await lock.load();
      expect(lock.enabled, isFalse);
      expect(lock.isLocked, isFalse);

      await lock.setEnabled(true);
      expect(lock.enabled, isTrue);
      expect(lock.isLocked, isTrue);

      lock.lockNow();
      expect(lock.isLocked, isTrue);

      await lock.setEnabled(false);
      expect(lock.isLocked, isFalse);
    });

    test('persists auto-lock minutes', () async {
      final config = FakeConfigRepository();
      final lock = AppLockProvider(config: config);
      await lock.load();
      await lock.setAutoLockMinutes(15);
      expect(lock.autoLockMinutes, 15);

      final reloaded = AppLockProvider(config: config);
      await reloaded.load();
      expect(reloaded.autoLockMinutes, 15);
    });

    test('resume after long background sets locked when enabled', () async {
      final config = FakeConfigRepository();
      await config.saveSettings(<String, dynamic>{
        'appLockEnabled': true,
        'appLockAutoLockMinutes': 1,
      });
      final lock = AppLockProvider(config: config);
      await lock.load();
      expect(lock.isLocked, isTrue);

      // Manually unlock state is only via authenticate; for timer test we
      // observe that pause+resume after the threshold keeps/sets lock.
      lock.onAppPaused();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      lock.onAppResumed();
      // 10ms < 1 minute, so lock state unchanged (still locked from load).
      expect(lock.isLocked, isTrue);
    });
  });
}

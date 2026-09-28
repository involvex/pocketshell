import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/config_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConfigService.init();
  });

  group('transformStickyInput', () {
    test('Ctrl+X encodes to 0x18', () {
      expect(
        SSHProvider.transformStickyInput('x', ctrl: true, alt: false),
        '\x18',
      );
      expect(
        SSHProvider.transformStickyInput('X', ctrl: true, alt: false),
        '\x18',
      );
    });

    test('Ctrl+Q encodes to 0x11 (nano essentials)', () {
      expect(
        SSHProvider.transformStickyInput('q', ctrl: true, alt: false),
        '\x11',
      );
      expect(
        SSHProvider.transformStickyInput('o', ctrl: true, alt: false),
        '\x0f',
      );
    });

    test('Alt+F encodes to ESC + upper', () {
      expect(
        SSHProvider.transformStickyInput('f', ctrl: false, alt: true),
        '\x1bF',
      );
    });

    test('no modifiers returns null', () {
      expect(
        SSHProvider.transformStickyInput('x', ctrl: false, alt: false),
        isNull,
      );
    });

    test('multi-char output (paste/sequences) is not transformed', () {
      expect(
        SSHProvider.transformStickyInput('hello', ctrl: true, alt: false),
        isNull,
      );
      expect(
        SSHProvider.transformStickyInput('\x1b[A', ctrl: true, alt: false),
        isNull,
      );
    });

    test('Ctrl wins when both armed', () {
      expect(
        SSHProvider.transformStickyInput('x', ctrl: true, alt: true),
        '\x18',
      );
    });

    test('Ctrl+digit has no encoding', () {
      expect(
        SSHProvider.transformStickyInput('3', ctrl: true, alt: false),
        isNull,
      );
    });
  });

  group('pending modifier toggles', () {
    test('toggle arms and disarms', () {
      final provider = SSHProvider();
      expect(provider.hasPendingModifiers, isFalse);

      provider.togglePendingCtrl();
      expect(provider.pendingCtrl, isTrue);
      expect(provider.hasPendingModifiers, isTrue);

      provider.togglePendingCtrl();
      expect(provider.hasPendingModifiers, isFalse);

      provider.togglePendingAlt();
      expect(provider.pendingAlt, isTrue);

      provider.clearPendingModifiers();
      expect(provider.hasPendingModifiers, isFalse);
    });

    test('clear is a no-op when nothing armed', () {
      final provider = SSHProvider();
      provider.clearPendingModifiers();
      expect(provider.hasPendingModifiers, isFalse);
    });
  });
}

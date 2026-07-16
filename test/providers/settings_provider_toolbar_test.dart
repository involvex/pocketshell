import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/home_toolbar_action.dart';
import 'package:ssh_app/providers/settings_provider.dart';

void main() {
  group('pinned toolbar actions', () {
    test('defaults to connect and profiles', () {
      final SettingsProvider settings = SettingsProvider();

      expect(
        settings.pinnedToolbarActions,
        HomeToolbarActionX.defaultPinned,
      );
      expect(settings.isToolbarActionPinned(HomeToolbarAction.connect), isTrue);
      expect(
          settings.isToolbarActionPinned(HomeToolbarAction.profiles), isTrue);
      expect(
          settings.isToolbarActionPinned(HomeToolbarAction.snippets), isFalse);
    });
  });
}

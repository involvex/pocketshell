import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/widgets/shortcut_editor.dart';

Future<void> _pumpEditor(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await ConfigService.init();
  final SettingsProvider settings = SettingsProvider();

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MaterialApp(
        home: Scaffold(body: ShortcutEditor()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Add opens dialog and applies selected action', (tester) async {
    await _pumpEditor(tester);

    // Switch to Ctrl row (selected index 2)
    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add Shortcut'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ShortcutAction>), findsOneWidget);

    // Pick Ctrl+L from dropdown (implementation may use displayNameFor)
    await tester.tap(find.byType(DropdownButtonFormField<ShortcutAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ctrl+L (Clear)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+L'), findsWidgets);
    expect(find.text('Clear'), findsWidgets);
    expect(find.text('New Shortcut'), findsNothing);
  });
}

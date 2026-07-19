import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/widgets/shortcut_editor.dart';

void _setLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1600);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  _setLargeSurface(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await ConfigService.init();
  final SettingsProvider settings = SettingsProvider();
  await settings.updateShortcuts(KeyboardShortcut.defaults);

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

class _TestNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

Future<_TestNavigatorObserver> _pumpEditorRoute(WidgetTester tester) async {
  _setLargeSurface(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await ConfigService.init();
  final SettingsProvider settings = SettingsProvider();
  await settings.updateShortcuts(KeyboardShortcut.defaults);
  final _TestNavigatorObserver observer = _TestNavigatorObserver();

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const Scaffold(body: ShortcutEditor());
                        },
                      ),
                    );
                  },
                  child: const Text('Open Editor'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Editor'));
  await tester.pumpAndSettle();
  return observer;
}

void main() {
  testWidgets('Add opens dialog and applies selected action', (tester) async {
    await _pumpEditor(tester);

    // Switch to Ctrl row (selected index 2)
    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add Shortcut'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ShortcutAction>), findsOneWidget);

    // Pick Ctrl+A from dropdown so the inserted shortcut is unique.
    await tester.tap(find.byType(DropdownButtonFormField<ShortcutAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ctrl+A').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+A'), findsOneWidget);
    expect(find.text('Select All / Line Start'), findsOneWidget);
  });

  testWidgets('drag handle wiring reorders shortcuts within the selected row',
      (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableDragStartListener), findsWidgets);

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem?.call(0, 1);
    await tester.pumpAndSettle();

    final double dyD = tester.getTopLeft(find.text('Ctrl+D')).dy;
    final double dyC = tester.getTopLeft(find.text('Ctrl+C')).dy;
    expect(dyD < dyC, isTrue);
  });

  testWidgets('save shows snackbar and keeps editor open', (tester) async {
    final _TestNavigatorObserver observer = await _pumpEditorRoute(tester);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();

    expect(find.text('Shortcuts saved'), findsOneWidget);
    expect(find.text('Configure Shortcuts'), findsOneWidget);
    expect(observer.popCount, 0);
  });

  testWidgets('editor uses parent-owned scrolling for reorder list',
      (tester) async {
    await _pumpEditor(tester);

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );

    expect(list.shrinkWrap, isTrue);
    expect(list.buildDefaultDragHandles, isFalse);
    expect(list.primary, isFalse);
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
  });
}

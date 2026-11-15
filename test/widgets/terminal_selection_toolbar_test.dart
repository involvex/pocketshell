import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/widgets/terminal_selection_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpToolbar(
    WidgetTester tester, {
    required Terminal terminal,
    required TerminalController controller,
    required GlobalKey<TerminalViewState> viewKey,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: <Widget>[
                TerminalView(
                  key: viewKey,
                  terminal,
                  controller: controller,
                ),
                Positioned.fill(
                  child: TerminalSelectionToolbar(
                    viewKey: viewKey,
                    terminal: terminal,
                    controller: controller,
                    onPaste: () async {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows Copy when selection exists and copies text',
      (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello world\r\n');
    final TerminalController controller = TerminalController();
    final GlobalKey<TerminalViewState> viewKey =
        GlobalKey<TerminalViewState>();
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            clipboardText = args['text'] as String?;
          }
        }
        return null;
      },
    );

    await pumpToolbar(
      tester,
      terminal: terminal,
      controller: controller,
      viewKey: viewKey,
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('hello'));
    expect(controller.selection, isNull);
  });

  testWidgets('keeps selection when there is nothing to copy',
      (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello\r\n');
    final TerminalController controller = TerminalController();
    final GlobalKey<TerminalViewState> viewKey =
        GlobalKey<TerminalViewState>();
    // Collapsed exclusive range → empty getText.
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(0, 0),
    );

    await pumpToolbar(
      tester,
      terminal: terminal,
      controller: controller,
      viewKey: viewKey,
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(find.text('Nothing to copy'), findsOneWidget);
  });

  testWidgets('hides when selection is cleared', (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello\r\n');
    final TerminalController controller = TerminalController();
    final GlobalKey<TerminalViewState> viewKey =
        GlobalKey<TerminalViewState>();
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );

    await pumpToolbar(
      tester,
      terminal: terminal,
      controller: controller,
      viewKey: viewKey,
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    controller.clearSelection();
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
  });
}

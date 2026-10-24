import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/widgets/terminal_selection_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows Copy when selection exists and copies text',
      (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello world\r\n');
    final TerminalController controller = TerminalController();
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalSelectionToolbar(
            terminal: terminal,
            controller: controller,
            onPaste: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('hello'));
    expect(controller.selection, isNull);
  });

  testWidgets('hides when selection is cleared', (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello\r\n');
    final TerminalController controller = TerminalController();
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalSelectionToolbar(
            terminal: terminal,
            controller: controller,
            onPaste: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Copy'), findsOneWidget);
    controller.clearSelection();
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
  });
}

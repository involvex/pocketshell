import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/widgets/terminal_selection_shield.dart';

void main() {
  testWidgets('shield hidden without selection, shown with selection',
      (WidgetTester tester) async {
    final Terminal terminal = Terminal(maxLines: 100);
    terminal.write('hello world\r\n');
    final TerminalController controller = TerminalController();
    final GlobalKey<TerminalViewState> viewKey =
        GlobalKey<TerminalViewState>();

    await tester.pumpWidget(
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
                TerminalSelectionShield(
                  viewKey: viewKey,
                  terminal: terminal,
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNothing);

    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );
    await tester.pump();

    expect(find.byType(GestureDetector), findsWidgets);

    // Tap should not clear selection (shield absorbs).
    await tester.tap(find.byType(ColoredBox).last);
    await tester.pump();
    // Flush double-tap timeout from GestureDetector.
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.selection, isNotNull);
  });
}

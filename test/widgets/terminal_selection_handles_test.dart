import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/widgets/terminal_selection_handles.dart';

void main() {
  testWidgets('handles hidden without selection, shown with selection',
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
                Positioned.fill(
                  child: TerminalSelectionHandles(
                    viewKey: viewKey,
                    terminal: terminal,
                    controller: controller,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('selection-handle-base')), findsNothing);
    expect(
        find.byKey(const ValueKey('selection-handle-extent')), findsNothing);

    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('selection-handle-base')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('selection-handle-extent')), findsOneWidget);

    controller.clearSelection();
    await tester.pump();

    expect(find.byKey(const ValueKey('selection-handle-base')), findsNothing);
  });
}

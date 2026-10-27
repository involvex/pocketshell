import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_clipboard.dart';
import 'package:ssh_app/utils/terminal_selection.dart';

/// Compact action bar shown while the terminal has an active selection.
class TerminalSelectionToolbar extends StatelessWidget {
  const TerminalSelectionToolbar({
    required this.terminal,
    required this.controller,
    required this.onPaste,
    super.key,
  });

  final Terminal terminal;
  final TerminalController controller;
  final Future<void> Function() onPaste;

  Future<void> _copy(BuildContext context, {required bool clearAfter}) async {
    final String? text = selectedTerminalText(terminal, controller);
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to copy')),
        );
      }
      return;
    }
    await TerminalClipboard.copyText(text);
    if (clearAfter) {
      controller.clearSelection();
    }
    if (context.mounted) {
      final int chars = text.length;
      final String label =
          chars == 1 ? 'Copied 1 character' : 'Copied $chars characters';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );
    }
  }

  void _selectAll() {
    controller.setSelection(
      terminal.buffer.createAnchor(
        0,
        terminal.buffer.height - terminal.viewHeight,
      ),
      terminal.buffer.createAnchor(
        terminal.viewWidth,
        terminal.buffer.height - 1,
      ),
      mode: SelectionMode.line,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final bool hasSelection = controller.selection != null;
        if (!hasSelection) {
          return const SizedBox.shrink();
        }
        final ColorScheme colors = Theme.of(context).colorScheme;
        final ButtonStyle actionStyle = TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        return Material(
          elevation: 1,
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton.icon(
                    style: actionStyle,
                    onPressed: () => _copy(context, clearAfter: true),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                  TextButton.icon(
                    style: actionStyle,
                    onPressed: _selectAll,
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select all'),
                  ),
                  TextButton.icon(
                    style: actionStyle,
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
                  TextButton.icon(
                    style: actionStyle,
                    onPressed: () async {
                      await onPaste();
                      controller.clearSelection();
                    },
                    icon: const Icon(Icons.paste, size: 16),
                    label: const Text('Paste'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

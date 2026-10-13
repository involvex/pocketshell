import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

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

  String? _selectedText() {
    final BufferRange? selection = controller.selection;
    if (selection == null) {
      return null;
    }
    final String text = terminal.buffer.getText(selection);
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  Future<void> _copy(BuildContext context) async {
    final String? text = _selectedText();
    if (text == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
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
        return Material(
          color: const Color(0xFF16213E),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select all'),
                  ),
                  TextButton.icon(
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
                  TextButton.icon(
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

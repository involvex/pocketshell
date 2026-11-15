import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_clipboard.dart';
import 'package:ssh_app/utils/terminal_selection.dart';
import 'package:ssh_app/utils/terminal_selection_range.dart';

bool _isAttached(dynamic render) => (render as RenderBox).attached;

Offset _localToGlobal(dynamic render, Offset point) =>
    (render as RenderBox).localToGlobal(point);

/// Floating action bar shown near an active terminal selection.
class TerminalSelectionToolbar extends StatefulWidget {
  const TerminalSelectionToolbar({
    required this.viewKey,
    required this.terminal,
    required this.controller,
    required this.onPaste,
    this.scrollController,
    super.key,
  });

  final GlobalKey<TerminalViewState> viewKey;
  final Terminal terminal;
  final TerminalController controller;
  final Future<void> Function() onPaste;
  final ScrollController? scrollController;

  @override
  State<TerminalSelectionToolbar> createState() =>
      _TerminalSelectionToolbarState();
}

class _TerminalSelectionToolbarState extends State<TerminalSelectionToolbar> {
  ScrollController? _scrollController;
  VoidCallback? _scrollListener;
  bool _layoutRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    _attachScrollController(widget.scrollController);
  }

  @override
  void didUpdateWidget(TerminalSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      _detachScrollController();
      _attachScrollController(widget.scrollController);
    }
  }

  @override
  void dispose() {
    _detachScrollController();
    super.dispose();
  }

  void _attachScrollController(ScrollController? controller) {
    _scrollController = controller;
    if (controller == null) {
      return;
    }
    _scrollListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    controller.addListener(_scrollListener!);
  }

  void _detachScrollController() {
    if (_scrollController != null && _scrollListener != null) {
      _scrollController!.removeListener(_scrollListener!);
    }
    _scrollController = null;
    _scrollListener = null;
  }

  void _scheduleLayoutRetry() {
    if (_layoutRetryScheduled || !mounted) {
      return;
    }
    _layoutRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutRetryScheduled = false;
      if (mounted && widget.controller.selection != null) {
        setState(() {});
      }
    });
  }

  Offset? _toLocal(dynamic render, CellOffset cell) {
    final RenderBox? self = context.findRenderObject() as RenderBox?;
    if (self == null || !self.attached) {
      return null;
    }
    if (!_isAttached(render)) {
      return null;
    }
    final Offset cellTopLeft = render.getOffset(cell) as Offset;
    final Offset global = _localToGlobal(render, cellTopLeft);
    return self.globalToLocal(global);
  }

  Future<void> _copy(BuildContext context) async {
    final String? text =
        selectedTerminalText(widget.terminal, widget.controller);
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to copy')),
        );
      }
      // Keep selection so the user can adjust handles and retry.
      return;
    }
    final String sanitized = TerminalClipboard.sanitize(text);
    final bool ok = await TerminalClipboard.copyText(sanitized);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy to clipboard')),
        );
      }
      return;
    }
    // Clear after copy; native side re-asserts the clip shortly after so
    // focus/IME churn cannot wipe what Gboard / Phone Link should see.
    widget.controller.clearSelection();
    if (context.mounted) {
      final int chars = sanitized.length;
      final String label =
          chars == 1 ? 'Copied 1 character' : 'Copied $chars characters';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );
    }
  }

  void _selectAll() {
    widget.controller.setSelection(
      widget.terminal.buffer.createAnchor(
        0,
        widget.terminal.buffer.height - widget.terminal.viewHeight,
      ),
      widget.terminal.buffer.createAnchor(
        widget.terminal.viewWidth,
        widget.terminal.buffer.height - 1,
      ),
      mode: SelectionMode.line,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        if (mounted) {
          setState(() {});
        }
        return false;
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final BufferRange? selection = widget.controller.selection;
          final TerminalViewState? state = widget.viewKey.currentState;
          if (selection == null || state == null) {
            return const SizedBox.shrink();
          }
          late final dynamic render;
          try {
            render = state.renderTerminal;
          } catch (_) {
            _scheduleLayoutRetry();
            return const SizedBox.shrink();
          }

          final BufferRange normalized = selection.normalized;
          final Offset? base =
              _toLocal(render, baseHandleCell(normalized));
          final Offset? extent =
              _toLocal(render, extentHandleCell(normalized));
          if (base == null || extent == null) {
            _scheduleLayoutRetry();
            return const SizedBox.shrink();
          }

          final RenderBox? self = context.findRenderObject() as RenderBox?;
          final double maxWidth = self?.size.width ?? 320;
          final double maxHeight = self?.size.height ?? 480;

          final double anchorX = (base.dx + extent.dx) / 2;
          final double preferAboveY = extent.dy < base.dy ? extent.dy : base.dy;
          const double barHeight = 44;
          const double gap = 8;
          final bool placeBelow = preferAboveY < barHeight + gap + 24;
          final double top = placeBelow
              ? (base.dy > extent.dy ? base.dy : extent.dy) + 28
              : preferAboveY - barHeight - gap;
          final double clampedTop =
              top.clamp(4.0, (maxHeight - barHeight - 4).clamp(4.0, maxHeight));

          final ColorScheme colors = Theme.of(context).colorScheme;
          final ButtonStyle primaryStyle = FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
          final ButtonStyle actionStyle = TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );

          const double barMaxWidth = 320;
          final double left = (anchorX - barMaxWidth / 2)
              .clamp(4.0, (maxWidth - barMaxWidth - 4).clamp(4.0, maxWidth));

          return Stack(
            children: <Widget>[
              Positioned(
                left: left,
                top: clampedTop,
                width: barMaxWidth.clamp(0, maxWidth - 8),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: colors.surfaceContainerHighest,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FilledButton.icon(
                            style: primaryStyle,
                            onPressed: () => _copy(context),
                            icon: const Icon(Icons.copy, size: 18),
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
                            onPressed: widget.controller.clearSelection,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                          ),
                          TextButton.icon(
                            style: actionStyle,
                            onPressed: () async {
                              await widget.onPaste();
                              widget.controller.clearSelection();
                            },
                            icon: const Icon(Icons.paste, size: 16),
                            label: const Text('Paste'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

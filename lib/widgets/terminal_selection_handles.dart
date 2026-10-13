import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Draggable Android-style selection handles for the terminal.
///
/// xterm paints the selection highlight but offers no touch handles, so a
/// long-press leaves the user with no way to adjust the range. This layer
/// sits on top of the [TerminalView] (identified by [viewKey]) and renders
/// a start/end handle that can be dragged to resize the selection in cell
/// units via [TerminalController.setSelection].
class TerminalSelectionHandles extends StatefulWidget {
  const TerminalSelectionHandles({
    required this.viewKey,
    required this.terminal,
    required this.controller,
    super.key,
  });

  final GlobalKey<TerminalViewState> viewKey;
  final Terminal terminal;
  final TerminalController controller;

  @override
  State<TerminalSelectionHandles> createState() =>
      _TerminalSelectionHandlesState();
}

/// Bridges xterm's [Terminal] (which uses its own observable mixin instead
/// of [Listenable]) into a [Listenable] so handle positions track output.
class _TerminalListenable extends ChangeNotifier {
  _TerminalListenable(this._terminal) {
    _terminal.addListener(_onChange);
  }

  final Terminal _terminal;

  void _onChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    _terminal.removeListener(_onChange);
    super.dispose();
  }
}

class _TerminalSelectionHandlesState extends State<TerminalSelectionHandles> {
  late final _TerminalListenable _terminalListenable;

  @override
  void initState() {
    super.initState();
    _terminalListenable = _TerminalListenable(widget.terminal);
  }

  @override
  void didUpdateWidget(TerminalSelectionHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.terminal, widget.terminal)) {
      _terminalListenable.dispose();
      _terminalListenable = _TerminalListenable(widget.terminal);
    }
  }

  @override
  void dispose() {
    _terminalListenable.dispose();
    super.dispose();
  }

  /// Pixel position of [cell] within this layer, or null when the terminal
  /// view has no laid-out render object yet.
  ///
  /// The render object is xterm's internal `RenderTerminal`, which is not
  /// part of the public API, so it is driven through `dynamic` with explicit
  /// casts on every result. Box access goes through single-expression
  /// helpers: an inline `as` would otherwise promote the local and hide
  /// the dynamic interface from the analyzer.
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

  void _moveHandle({
    required DragUpdateDetails details,
    required bool isBase,
  }) {
    final TerminalViewState? state = widget.viewKey.currentState;
    if (state == null) {
      return;
    }
    final dynamic render = state.renderTerminal;
    final Offset local = _globalToLocal(render, details.globalPosition);
    final CellOffset cell = _cellAt(render, local);
    final BufferRange? current = widget.controller.selection;
    if (current == null) {
      return;
    }
    final BufferRange normalized = current.normalized;
    if (isBase) {
      widget.controller.setSelection(
        widget.terminal.buffer.createAnchorFromOffset(cell),
        widget.terminal.buffer.createAnchorFromOffset(normalized.end),
      );
    } else {
      widget.controller.setSelection(
        widget.terminal.buffer.createAnchorFromOffset(normalized.begin),
        widget.terminal.buffer.createAnchorFromOffset(cell),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // Keep handles glued to their cells while scrolling.
        if (mounted) {
          setState(() {});
        }
        return false;
      },
      child: ListenableBuilder(
        listenable:
            Listenable.merge(<Listenable>[widget.controller, _terminalListenable]),
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
            // View not laid out yet — skip this frame.
            return const SizedBox.shrink();
          }
          final BufferRange normalized = selection.normalized;
          final Offset? base = _toLocal(render, normalized.begin);
          final Offset? extent = _toLocal(render, normalized.end);
          if (base == null || extent == null) {
            return const SizedBox.shrink();
          }
          final Color accent = Theme.of(context).colorScheme.primary;
          return Stack(
            children: <Widget>[
              _Handle(
                position: base,
                color: accent,
                below: true,
                onPanUpdate: (DragUpdateDetails d) =>
                    _moveHandle(details: d, isBase: true),
              ),
              _Handle(
                position: extent,
                color: accent,
                below: false,
                onPanUpdate: (DragUpdateDetails d) =>
                    _moveHandle(details: d, isBase: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool _isAttached(dynamic render) => (render as RenderBox).attached;

Offset _localToGlobal(dynamic render, Offset point) =>
    (render as RenderBox).localToGlobal(point);

Offset _globalToLocal(dynamic render, Offset point) =>
    (render as RenderBox).globalToLocal(point);

CellOffset _cellAt(dynamic render, Offset point) =>
    render.getCellOffset(point) as CellOffset;

class _Handle extends StatelessWidget {
  const _Handle({
    required this.position,
    required this.color,
    required this.below,
    required this.onPanUpdate,
  });

  final Offset position;
  final Color color;
  final bool below;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    const double dotSize = 16;
    const double stemHeight = 28;
    const double stemWidth = 3;
    const double touchTarget = 44;

    final Widget dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    final Widget stem =
        Container(width: stemWidth, height: stemHeight, color: color);

    // Anchor the dot center on the cell position.
    final double left = position.dx - touchTarget / 2;
    final double top = below
        ? position.dy - dotSize / 2
        : position.dy - stemHeight - dotSize + dotSize / 2;

    return Positioned(
      left: left,
      top: top,
      width: touchTarget,
      height: dotSize + stemHeight,
      child: GestureDetector(
        key: ValueKey<String>(
          below ? 'selection-handle-base' : 'selection-handle-extent',
        ),
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onPanUpdate,
        child: Center(
          child: below
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[dot, stem],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[stem, dot],
                ),
        ),
      ),
    );
  }
}

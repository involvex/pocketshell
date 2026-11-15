import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_selection_range.dart';

/// Draggable Android-style selection handles for the terminal.
///
/// xterm paints the selection highlight but offers no touch handles, so a
/// long-press leaves the user with no way to adjust the range. This layer
/// sits on top of the [TerminalView] (identified by [viewKey]) and renders
/// a start/end handle that can be dragged to resize the selection in cell
/// units via [TerminalController.setSelection].
///
/// Extent positioning uses exclusive-end semantics (see
/// [extentHandleCell] / [moveSelectionHandle]).
class TerminalSelectionHandles extends StatefulWidget {
  const TerminalSelectionHandles({
    required this.viewKey,
    required this.terminal,
    required this.controller,
    this.scrollController,
    super.key,
  });

  final GlobalKey<TerminalViewState> viewKey;
  final Terminal terminal;
  final TerminalController controller;
  final ScrollController? scrollController;

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
  late _TerminalListenable _terminalListenable;
  ScrollController? _scrollController;
  VoidCallback? _scrollListener;
  bool _layoutRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    _terminalListenable = _TerminalListenable(widget.terminal);
    _attachScrollController(widget.scrollController);
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

  @override
  void didUpdateWidget(TerminalSelectionHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.terminal, widget.terminal)) {
      _terminalListenable.dispose();
      _terminalListenable = _TerminalListenable(widget.terminal);
    }
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      _detachScrollController();
      _attachScrollController(widget.scrollController);
    }
  }

  @override
  void dispose() {
    _detachScrollController();
    _terminalListenable.dispose();
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

  void _onHandlePanStart() {
    HapticFeedback.selectionClick();
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
    moveSelectionHandle(
      terminal: widget.terminal,
      controller: widget.controller,
      current: current,
      finger: cell,
      isBase: isBase,
    );
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
            // View not laid out yet — retry next frame.
            _scheduleLayoutRetry();
            return const SizedBox.shrink();
          }
          final BufferRange normalized = selection.normalized;
          final Offset? baseTop =
              _toLocal(render, baseHandleCell(normalized));
          final Offset? extentTop =
              _toLocal(render, extentHandleCell(normalized));
          if (baseTop == null || extentTop == null) {
            _scheduleLayoutRetry();
            return const SizedBox.shrink();
          }
          // Anchor handles to the bottom of the cell like Android TextField.
          final double lineHeight = _lineHeight(render);
          final Offset base = Offset(baseTop.dx, baseTop.dy + lineHeight);
          final Offset extent =
              Offset(extentTop.dx, extentTop.dy + lineHeight);
          final Color accent = Theme.of(context).colorScheme.primary;
          return Stack(
            children: <Widget>[
              _AndroidHandle(
                position: base,
                color: accent,
                // Mirrored teardrop on the start edge (Android left handle).
                mirrored: true,
                onPanStart: _onHandlePanStart,
                onPanUpdate: (DragUpdateDetails d) =>
                    _moveHandle(details: d, isBase: true),
              ),
              _AndroidHandle(
                position: extent,
                color: accent,
                mirrored: false,
                onPanStart: _onHandlePanStart,
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

double _lineHeight(dynamic render) {
  try {
    return (render.lineHeight as num).toDouble();
  } on Object {
    try {
      return (render.cellSize as Size).height;
    } on Object {
      return 16;
    }
  }
}

/// Material-style teardrop handle hanging below the selection baseline.
class _AndroidHandle extends StatelessWidget {
  const _AndroidHandle({
    required this.position,
    required this.color,
    required this.mirrored,
    required this.onPanStart,
    required this.onPanUpdate,
  });

  final Offset position;
  final Color color;
  final bool mirrored;
  final VoidCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;

  static const double _size = 22;
  static const double _touchTarget = 48;

  @override
  Widget build(BuildContext context) {
    final Widget handle = CustomPaint(
      size: const Size(_size, _size),
      painter: _TextSelectionHandlePainter(color: color),
    );

    // Android: both handles sit under the line; start is mirrored.
    final Widget oriented = mirrored
        ? Transform.flip(flipX: true, child: handle)
        : handle;

    final double left = mirrored
        ? position.dx - _touchTarget + _size / 2
        : position.dx - _size / 2;
    final double top = position.dy - 2;

    return Positioned(
      left: left,
      top: top,
      width: _touchTarget,
      height: _touchTarget,
      child: GestureDetector(
        key: ValueKey<String>(
          mirrored ? 'selection-handle-base' : 'selection-handle-extent',
        ),
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onPanStart(),
        onPanUpdate: onPanUpdate,
        child: Align(
          alignment: mirrored ? Alignment.topRight : Alignment.topLeft,
          child: oriented,
        ),
      ),
    );
  }
}

/// Matches Flutter Material text-selection handle geometry (teardrop).
class _TextSelectionHandlePainter extends CustomPainter {
  const _TextSelectionHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double radius = size.width / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    final Path path = Path()
      ..moveTo(0, radius)
      ..lineTo(radius, 0)
      ..lineTo(radius * 2, radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

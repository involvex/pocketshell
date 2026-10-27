import 'package:material_ui/material_ui.dart';

/// Two-finger pinch that adjusts terminal font size.
///
/// Uses a translucent [Listener] so the terminal keeps one-finger scroll and
/// selection gestures; only two-pointer distance changes affect the size.
class TerminalPinchZoom extends StatefulWidget {
  const TerminalPinchZoom({
    required this.fontSize,
    required this.minFontSize,
    required this.maxFontSize,
    required this.onChanged,
    required this.onCommit,
    required this.child,
    super.key,
  });

  final double fontSize;
  final double minFontSize;
  final double maxFontSize;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;
  final Widget child;

  @override
  State<TerminalPinchZoom> createState() => _TerminalPinchZoomState();
}

class _TerminalPinchZoomState extends State<TerminalPinchZoom> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startDistance;
  double? _startFontSize;
  double? _lastEmitted;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _startDistance = _pointerDistance();
      _startFontSize = widget.fontSize;
      _lastEmitted = widget.fontSize;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    final startDistance = _startDistance;
    final startFontSize = _startFontSize;
    if (_pointers.length != 2 ||
        startDistance == null ||
        startFontSize == null ||
        startDistance < 8) {
      return;
    }

    final scale = _pointerDistance() / startDistance;
    final next = (startFontSize * scale).clamp(
      widget.minFontSize,
      widget.maxFontSize,
    );
    final rounded = next.roundToDouble();
    if (_lastEmitted == rounded) return;
    _lastEmitted = rounded;
    widget.onChanged(rounded);
  }

  void _onPointerUp(PointerEvent event) {
    final wasPinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (!wasPinching || _pointers.length >= 2) return;

    final committed = _lastEmitted ?? widget.fontSize;
    _startDistance = null;
    _startFontSize = null;
    _lastEmitted = null;
    widget.onCommit(committed);
  }

  double _pointerDistance() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }
}

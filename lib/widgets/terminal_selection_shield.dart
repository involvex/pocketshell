import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_selection_range.dart';

Offset _globalToLocal(dynamic render, Offset point) =>
    (render as RenderBox).globalToLocal(point);

/// Absorbs taps while a terminal selection is active so xterm cannot clear
/// it or re-request the IME, and supports touch drag to extend by character.
///
/// Long-press / double-tap on the shield re-selects a word under the finger.
/// Handle pans are owned by [TerminalSelectionHandles] layered above this.
class TerminalSelectionShield extends StatefulWidget {
  const TerminalSelectionShield({
    required this.viewKey,
    required this.terminal,
    required this.controller,
    super.key,
  });

  final GlobalKey<TerminalViewState> viewKey;
  final Terminal terminal;
  final TerminalController controller;

  @override
  State<TerminalSelectionShield> createState() =>
      _TerminalSelectionShieldState();
}

class _TerminalSelectionShieldState extends State<TerminalSelectionShield> {
  CellOffset? _dragBegin;
  bool _extending = false;

  dynamic get _render {
    final TerminalViewState? state = widget.viewKey.currentState;
    if (state == null) {
      return null;
    }
    try {
      return state.renderTerminal;
    } catch (_) {
      return null;
    }
  }

  CellOffset? _cellForGlobal(Offset global) {
    final dynamic render = _render;
    if (render == null) {
      return null;
    }
    final Offset local = _globalToLocal(render, global);
    return render.getCellOffset(local) as CellOffset;
  }

  void _selectWordAt(Offset global) {
    final dynamic render = _render;
    if (render == null) {
      return;
    }
    final Offset local = _globalToLocal(render, global);
    render.selectWord(local);
    HapticFeedback.selectionClick();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _selectWordAt(details.globalPosition);
    final BufferRange? selection = widget.controller.selection;
    if (selection != null) {
      _dragBegin = selection.normalized.begin;
      _extending = true;
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_extending) {
      return;
    }
    final CellOffset? begin = _dragBegin;
    final CellOffset? finger = _cellForGlobal(details.globalPosition);
    if (begin == null || finger == null) {
      return;
    }
    setCharacterSelection(
      terminal: widget.terminal,
      controller: widget.controller,
      begin: begin,
      extentFinger: finger,
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _extending = false;
    _dragBegin = null;
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _selectWordAt(details.globalPosition);
  }

  void _onPanStart(DragStartDetails details) {
    final BufferRange? selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    _dragBegin = selection.normalized.begin;
    _extending = true;
    HapticFeedback.selectionClick();
    final CellOffset? finger = _cellForGlobal(details.globalPosition);
    if (finger == null) {
      return;
    }
    setCharacterSelection(
      terminal: widget.terminal,
      controller: widget.controller,
      begin: _dragBegin!,
      extentFinger: finger,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_extending) {
      return;
    }
    final CellOffset? begin = _dragBegin;
    final CellOffset? finger = _cellForGlobal(details.globalPosition);
    if (begin == null || finger == null) {
      return;
    }
    setCharacterSelection(
      terminal: widget.terminal,
      controller: widget.controller,
      begin: begin,
      extentFinger: finger,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    _extending = false;
    _dragBegin = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        if (widget.controller.selection == null) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Absorb taps so xterm does not clear the selection.
            },
            onDoubleTapDown: _onDoubleTapDown,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        );
      },
    );
  }
}

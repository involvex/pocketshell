import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Suspends mouse/tap forwarding to the remote terminal while text is selected.
///
/// Prevents accidental clicks to vim/tmux when using the selection toolbar or
/// dragging handles. xterm still handles long-press and drag selection locally.
class TerminalSelectionInputGuard extends StatefulWidget {
  const TerminalSelectionInputGuard({
    required this.controller,
    required this.child,
    super.key,
  });

  final TerminalController controller;
  final Widget child;

  @override
  State<TerminalSelectionInputGuard> createState() =>
      _TerminalSelectionInputGuardState();
}

class _TerminalSelectionInputGuardState
    extends State<TerminalSelectionInputGuard> {
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSuspend);
    _syncSuspend();
  }

  @override
  void didUpdateWidget(TerminalSelectionInputGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_syncSuspend);
      widget.controller.addListener(_syncSuspend);
      _syncSuspend();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSuspend);
    if (_suspended) {
      widget.controller.setSuspendPointerInput(false);
    }
    super.dispose();
  }

  void _syncSuspend() {
    final bool shouldSuspend = widget.controller.selection != null;
    if (shouldSuspend == _suspended) {
      return;
    }
    _suspended = shouldSuspend;
    widget.controller.setSuspendPointerInput(shouldSuspend);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

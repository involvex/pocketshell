import 'package:xterm/xterm.dart';

/// Exclusive-end helpers matching xterm's [RenderTerminal.selectCharacters].
///
/// xterm stores selection ends as exclusive on the end line (`getText` uses
/// `i < end.x`). Mouse drag adds `+1` to the finger column when
/// `to.x >= from.x`; our touch handles must do the same.

/// Converts a drag from [from] to finger cell [to] into an exclusive end.
CellOffset exclusiveEndFromDrag({
  required CellOffset from,
  required CellOffset to,
}) {
  if (to.x >= from.x) {
    return CellOffset(to.x + 1, to.y);
  }
  return to;
}

/// Cell under the extent handle for a normalized selection with exclusive end.
///
/// Returns the last included cell so the handle sits on selected text, not on
/// the exclusive boundary past it.
CellOffset extentHandleCell(BufferRange normalized) {
  final CellOffset begin = normalized.begin;
  final CellOffset end = normalized.end;
  if (begin.isEqual(end)) {
    return begin;
  }
  if (end.x > 0) {
    return CellOffset(end.x - 1, end.y);
  }
  if (end.y > begin.y) {
    // Exclusive end at column 0 of a later line → last line ended at prior row.
    return CellOffset(0, end.y - 1);
  }
  return begin;
}

/// Inclusive cell under the base (start) handle.
CellOffset baseHandleCell(BufferRange normalized) => normalized.begin;

/// Builds anchors for a character selection from [begin] to finger [extent],
/// applying exclusive-end rules.
void setCharacterSelection({
  required Terminal terminal,
  required TerminalController controller,
  required CellOffset begin,
  required CellOffset extentFinger,
}) {
  final CellOffset exclusiveEnd = exclusiveEndFromDrag(
    from: begin,
    to: extentFinger,
  );
  controller.setSelection(
    terminal.buffer.createAnchorFromOffset(begin),
    terminal.buffer.createAnchorFromOffset(exclusiveEnd),
    mode: SelectionMode.line,
  );
}

/// Moves the base or extent handle to [finger], preserving exclusive-end
/// semantics for the extent side.
void moveSelectionHandle({
  required Terminal terminal,
  required TerminalController controller,
  required BufferRange current,
  required CellOffset finger,
  required bool isBase,
}) {
  final BufferRange normalized = current.normalized;
  if (isBase) {
    controller.setSelection(
      terminal.buffer.createAnchorFromOffset(finger),
      terminal.buffer.createAnchorFromOffset(normalized.end),
      mode: SelectionMode.line,
    );
    return;
  }
  setCharacterSelection(
    terminal: terminal,
    controller: controller,
    begin: normalized.begin,
    extentFinger: finger,
  );
}

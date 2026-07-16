import 'package:xterm/xterm.dart';

import 'terminal_enter_mapping.dart';

/// Wraps [defaultInputHandler] and remaps Enter / NumpadEnter.
class EnterMappingInputHandler implements TerminalInputHandler {
  EnterMappingInputHandler({
    required this.mapping,
    this.inner = defaultInputHandler,
  });

  TerminalEnterSends mapping;
  final TerminalInputHandler? inner;

  @override
  String? call(TerminalKeyboardEvent event) {
    if (event.key == TerminalKey.enter ||
        event.key == TerminalKey.numpadEnter) {
      return enterSequenceFor(mapping);
    }
    return inner?.call(event);
  }
}

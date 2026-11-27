import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import '../providers/settings_provider.dart';

class TerminalStyleBuilder {
  static String? fontFamilyName(TerminalFontFamily family) {
    return switch (family) {
      TerminalFontFamily.jetBrainsMono => 'JetBrainsMono',
      TerminalFontFamily.firaCode => 'FiraCode',
      TerminalFontFamily.spaceMono => 'SpaceMono',
      TerminalFontFamily.sourceCodePro => 'SourceCodePro',
      TerminalFontFamily.monospace => 'monospace',
      TerminalFontFamily.courierNew => 'Courier New',
      TerminalFontFamily.consolas => 'Consolas',
      TerminalFontFamily.menlo => 'Menlo',
    };
  }

  static TextStyle buildTextStyle(SettingsProvider settings) {
    final fontWeight = switch (settings.terminalFontWeight) {
      TerminalFontWeight.normal => FontWeight.normal,
      TerminalFontWeight.medium => FontWeight.w500,
      TerminalFontWeight.semiBold => FontWeight.w600,
      TerminalFontWeight.bold => FontWeight.bold,
    };
    final fontStyle = settings.terminalFontStyle == TerminalFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

    return TextStyle(
      fontSize: settings.terminalFontSize,
      fontFamily: fontFamilyName(settings.terminalFontFamily),
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
  }

  static TerminalStyle buildTerminalStyle(SettingsProvider settings) {
    final textStyle = buildTextStyle(settings);
    return TerminalStyle.fromTextStyle(textStyle);
  }
}

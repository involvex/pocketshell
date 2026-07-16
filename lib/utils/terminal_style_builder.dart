import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

import '../providers/settings_provider.dart';

class TerminalStyleBuilder {
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

    return switch (settings.terminalFontFamily) {
      TerminalFontFamily.jetBrainsMono => GoogleFonts.jetBrainsMono(
          fontSize: settings.terminalFontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.firaCode => GoogleFonts.firaCode(
          fontSize: settings.terminalFontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.spaceMono => GoogleFonts.spaceMono(
          fontSize: settings.terminalFontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.sourceCodePro => GoogleFonts.sourceCodePro(
          fontSize: settings.terminalFontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.monospace => TextStyle(
          fontSize: settings.terminalFontSize,
          fontFamily: 'monospace',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.courierNew => TextStyle(
          fontSize: settings.terminalFontSize,
          fontFamily: 'Courier New',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.consolas => TextStyle(
          fontSize: settings.terminalFontSize,
          fontFamily: 'Consolas',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      TerminalFontFamily.menlo => TextStyle(
          fontSize: settings.terminalFontSize,
          fontFamily: 'Menlo',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
    };
  }

  static TerminalStyle buildTerminalStyle(SettingsProvider settings) {
    final textStyle = buildTextStyle(settings);
    return TerminalStyle.fromTextStyle(textStyle);
  }
}

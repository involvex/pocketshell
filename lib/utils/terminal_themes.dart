import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Color palette applied to [TerminalView], independent of app ThemeData.
enum TerminalColorTheme {
  standard,
  hacker,
  dracula,
  solarizedDark,
  nord,
  monokai,
}

extension TerminalColorThemeX on TerminalColorTheme {
  String get displayName => switch (this) {
        TerminalColorTheme.standard => 'Default',
        TerminalColorTheme.hacker => 'Hacker',
        TerminalColorTheme.dracula => 'Dracula',
        TerminalColorTheme.solarizedDark => 'Solarized Dark',
        TerminalColorTheme.nord => 'Nord',
        TerminalColorTheme.monokai => 'Monokai',
      };

  static TerminalColorTheme fromStorage(String? value) {
    return TerminalColorTheme.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TerminalColorTheme.standard,
    );
  }

  TerminalTheme toTerminalTheme() {
    return switch (this) {
      TerminalColorTheme.standard => TerminalThemes.defaultTheme,
      TerminalColorTheme.hacker => _hacker,
      TerminalColorTheme.dracula => _dracula,
      TerminalColorTheme.solarizedDark => _solarizedDark,
      TerminalColorTheme.nord => _nord,
      TerminalColorTheme.monokai => _monokai,
    };
  }
}

const TerminalTheme _hacker = TerminalTheme(
  cursor: Color(0xFFAEAFAD),
  selection: Color(0xFFAEAFAD),
  foreground: Colors.greenAccent,
  background: Color(0xFF000000),
  black: Color(0xFF000000),
  red: Color(0xFFCD3131),
  green: Color(0xFF0DBC79),
  yellow: Color(0xFFE5E510),
  blue: Color(0xFF2472C8),
  magenta: Color(0xFFBC3FBC),
  cyan: Color(0xFF11A8CD),
  white: Color(0xFFE5E5E5),
  brightBlack: Color(0xFF666666),
  brightRed: Color(0xFFF14C4C),
  brightGreen: Color(0xFF23D18B),
  brightYellow: Color(0xFFF5F543),
  brightBlue: Color(0xFF3B8EEA),
  brightMagenta: Color(0xFFD670D6),
  brightCyan: Color(0xFF29B8DB),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFFFFF2B),
  searchHitBackgroundCurrent: Color(0xFF31FF26),
  searchHitForeground: Color(0xFF000000),
);

const TerminalTheme _dracula = TerminalTheme(
  cursor: Color(0xFFF8F8F2),
  selection: Color(0xFF44475A),
  foreground: Color(0xFFF8F8F2),
  background: Color(0xFF282A36),
  black: Color(0xFF21222C),
  red: Color(0xFFFF5555),
  green: Color(0xFF50FA7B),
  yellow: Color(0xFFF1FA8C),
  blue: Color(0xFFBD93F9),
  magenta: Color(0xFFFF79C6),
  cyan: Color(0xFF8BE9FD),
  white: Color(0xFFF8F8F2),
  brightBlack: Color(0xFF6272A4),
  brightRed: Color(0xFFFF6E6E),
  brightGreen: Color(0xFF69FF94),
  brightYellow: Color(0xFFFFFFA5),
  brightBlue: Color(0xFFD6ACFF),
  brightMagenta: Color(0xFFFF92DF),
  brightCyan: Color(0xFFA4FFFF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFF1FA8C),
  searchHitBackgroundCurrent: Color(0xFF50FA7B),
  searchHitForeground: Color(0xFF282A36),
);

const TerminalTheme _solarizedDark = TerminalTheme(
  cursor: Color(0xFF839496),
  selection: Color(0xFF073642),
  foreground: Color(0xFF839496),
  background: Color(0xFF002B36),
  black: Color(0xFF073642),
  red: Color(0xFFDC322F),
  green: Color(0xFF859900),
  yellow: Color(0xFFB58900),
  blue: Color(0xFF268BD2),
  magenta: Color(0xFFD33682),
  cyan: Color(0xFF2AA198),
  white: Color(0xFFEEE8D5),
  brightBlack: Color(0xFF002B36),
  brightRed: Color(0xFFCB4B16),
  brightGreen: Color(0xFF586E75),
  brightYellow: Color(0xFF657B83),
  brightBlue: Color(0xFF839496),
  brightMagenta: Color(0xFF6C71C4),
  brightCyan: Color(0xFF93A1A1),
  brightWhite: Color(0xFFFDF6E3),
  searchHitBackground: Color(0xFFB58900),
  searchHitBackgroundCurrent: Color(0xFF859900),
  searchHitForeground: Color(0xFF002B36),
);

const TerminalTheme _nord = TerminalTheme(
  cursor: Color(0xFFD8DEE9),
  selection: Color(0xFF434C5E),
  foreground: Color(0xFFD8DEE9),
  background: Color(0xFF2E3440),
  black: Color(0xFF3B4252),
  red: Color(0xFFBF616A),
  green: Color(0xFFA3BE8C),
  yellow: Color(0xFFEBCB8B),
  blue: Color(0xFF81A1C1),
  magenta: Color(0xFFB48EAD),
  cyan: Color(0xFF88C0D0),
  white: Color(0xFFE5E9F0),
  brightBlack: Color(0xFF4C566A),
  brightRed: Color(0xFFBF616A),
  brightGreen: Color(0xFFA3BE8C),
  brightYellow: Color(0xFFEBCB8B),
  brightBlue: Color(0xFF81A1C1),
  brightMagenta: Color(0xFFB48EAD),
  brightCyan: Color(0xFF8FBCBB),
  brightWhite: Color(0xFFECEFF4),
  searchHitBackground: Color(0xFFEBCB8B),
  searchHitBackgroundCurrent: Color(0xFFA3BE8C),
  searchHitForeground: Color(0xFF2E3440),
);

const TerminalTheme _monokai = TerminalTheme(
  cursor: Color(0xFFF8F8F2),
  selection: Color(0xFF49483E),
  foreground: Color(0xFFF8F8F2),
  background: Color(0xFF272822),
  black: Color(0xFF272822),
  red: Color(0xFFF92672),
  green: Color(0xFFA6E22E),
  yellow: Color(0xFFF4BF75),
  blue: Color(0xFF66D9EF),
  magenta: Color(0xFFAE81FF),
  cyan: Color(0xFFA1EFE4),
  white: Color(0xFFF8F8F2),
  brightBlack: Color(0xFF75715E),
  brightRed: Color(0xFFF92672),
  brightGreen: Color(0xFFA6E22E),
  brightYellow: Color(0xFFF4BF75),
  brightBlue: Color(0xFF66D9EF),
  brightMagenta: Color(0xFFAE81FF),
  brightCyan: Color(0xFFA1EFE4),
  brightWhite: Color(0xFFF9F8F5),
  searchHitBackground: Color(0xFFF4BF75),
  searchHitBackgroundCurrent: Color(0xFFA6E22E),
  searchHitForeground: Color(0xFF272822),
);

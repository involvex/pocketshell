import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/utils/terminal_style_builder.dart';

void main() {
  test('bundled families map to local fontFamily names', () {
    expect(
      TerminalStyleBuilder.fontFamilyName(TerminalFontFamily.jetBrainsMono),
      'JetBrainsMono',
    );
    expect(
      TerminalStyleBuilder.fontFamilyName(TerminalFontFamily.firaCode),
      'FiraCode',
    );
    expect(
      TerminalStyleBuilder.fontFamilyName(TerminalFontFamily.monospace),
      'monospace',
    );
  });
}

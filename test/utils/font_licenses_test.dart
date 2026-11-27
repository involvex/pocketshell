import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OFL asset loads and is registered for the licenses page', () async {
    registerBundledFontLicenses();
    final List<LicenseEntry> entries = await LicenseRegistry.licenses.toList();
    final LicenseEntry ofl = entries.firstWhere(
      (LicenseEntry e) => e.packages.contains('JetBrains Mono'),
    );
    expect(ofl.packages, containsAll(<String>['Fira Code', 'Space Mono']));
    final String text =
        ofl.paragraphs.map((LicenseParagraph p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains('JetBrains Mono'));
  });
}

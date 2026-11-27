import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String kOflAssetPath = 'assets/fonts/OFL.txt';

/// Registers bundled OFL terminal fonts on the in-app licenses page.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final String ofl = await rootBundle.loadString(kOflAssetPath);
    yield LicenseEntryWithLineBreaks(
      const <String>[
        'JetBrains Mono',
        'Fira Code',
        'Space Mono',
        'Source Code Pro',
      ],
      ofl,
    );
  });
}

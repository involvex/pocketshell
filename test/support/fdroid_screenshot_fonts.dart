import 'dart:io';

import 'package:flutter/services.dart';

/// Load Roboto + MaterialIcons so Fastlane shots are not Ahem tofu.
Future<void> loadFdroidScreenshotFonts() async {
  final String flutterRoot = _flutterRoot();
  final Directory fonts = Directory(
    '$flutterRoot/bin/cache/artifacts/material_fonts',
  );

  await _loadFamily('Roboto', <File>[
    File('${fonts.path}/roboto-regular.ttf'),
    File('${fonts.path}/roboto-medium.ttf'),
    File('${fonts.path}/roboto-bold.ttf'),
    File('${fonts.path}/roboto-italic.ttf'),
  ]);
  await _loadFamily('MaterialIcons', <File>[
    File('${fonts.path}/materialicons-regular.otf'),
  ]);
  await _loadFamily('JetBrainsMono', <File>[
    File('assets/fonts/JetBrainsMono-Regular.ttf'),
    File('assets/fonts/JetBrainsMono-Bold.ttf'),
  ]);
  // Default terminal family is "monospace"; alias the bundled OFL font so
  // Fastlane Client shots are not Ahem tofu.
  await _loadFamily('monospace', <File>[
    File('assets/fonts/JetBrainsMono-Regular.ttf'),
  ]);
}

String _flutterRoot() {
  final String? fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  throw StateError('FLUTTER_ROOT is not set; run via flutter test.');
}

Future<void> _loadFamily(String family, List<File> files) async {
  final FontLoader loader = FontLoader(family);
  var added = false;
  for (final File file in files) {
    if (!file.existsSync()) {
      continue;
    }
    final Uint8List bytes = file.readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    added = true;
  }
  if (!added) {
    throw StateError('No files for font family $family');
  }
  await loader.load();
}

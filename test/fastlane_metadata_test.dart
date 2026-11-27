import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int width, int height}) pngSize(File file) {
  final Uint8List bytes = file.readAsBytesSync();
  final ByteData data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16, Endian.big),
    height: data.getUint32(20, Endian.big),
  );
}

void main() {
  const String root = 'fastlane/metadata/android/en-US';

  test('title is within the F-Droid / Play 50-character limit', () {
    final String title = File('$root/title.txt').readAsStringSync().trim();
    expect(title, isNotEmpty);
    expect(title.length, lessThanOrEqualTo(50));
  });

  test('short description is within the 80-character limit', () {
    final String text =
        File('$root/short_description.txt').readAsStringSync().trim();
    expect(text, isNotEmpty);
    expect(text.length, lessThanOrEqualTo(80));
  });

  test('full description is present and under 4000 characters', () {
    final String text =
        File('$root/full_description.txt').readAsStringSync().trim();
    expect(text, isNotEmpty);
    expect(text.length, lessThanOrEqualTo(4000));
  });

  test('changelog files stay under 500 characters', () {
    final Directory dir = Directory('$root/changelogs');
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.txt'))
        .toList();
    expect(files, isNotEmpty);
    for (final File file in files) {
      final String body = file.readAsStringSync();
      expect(
        body.length,
        lessThanOrEqualTo(500),
        reason: file.path,
      );
    }
  });

  test('icon is at least 256px and feature graphic is 1024x500', () {
    final File icon = File('$root/images/icon.png');
    final File feature = File('$root/images/featureGraphic.png');
    expect(icon.existsSync(), isTrue);
    expect(feature.existsSync(), isTrue);
    final ({int width, int height}) iconSize = pngSize(icon);
    expect(iconSize.width, greaterThanOrEqualTo(256));
    expect(iconSize.height, iconSize.width);
    final ({int width, int height}) graphic = pngSize(feature);
    expect(graphic.width, 1024);
    expect(graphic.height, 500);
  });

  test('at least four phone screenshots stay within the 2:1 aspect limit', () {
    final Directory dir = Directory('$root/images/phoneScreenshots');
    final List<File> pngs = dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.png'))
        .toList();
    expect(
      pngs.length,
      greaterThanOrEqualTo(4),
      reason:
          'Run scripts/render-fdroid-screenshots.ps1 (or the device capture script).',
    );
    for (final File png in pngs) {
      final ({int width, int height}) size = pngSize(png);
      expect(size.height / size.width, lessThanOrEqualTo(2.0),
          reason: png.path);
    }
    final List<File> extras = dir
        .listSync()
        .whereType<File>()
        .where((File f) => !f.path.toLowerCase().endsWith('.png'))
        .toList();
    expect(
      extras,
      isEmpty,
      reason: 'F-Droid reads every file in phoneScreenshots/; keep only PNGs',
    );
  });

  test('FOSS listing files exist and google_fonts is not a dependency', () {
    expect(File('LICENSE').existsSync(), isTrue);
    expect(File('PRIVACY.md').existsSync(), isTrue);
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    expect(File('THIRD_PARTY.md').existsSync(), isTrue);
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('google_fonts'), isFalse);
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:allowBackup="false"'),
    );
    final bool vendorGif = Directory('packages/home_widget')
        .listSync(recursive: true)
        .whereType<File>()
        .any((File f) => f.path.toLowerCase().endsWith('.gif'));
    expect(vendorGif, isFalse, reason: 'F-Droid issuebot flags unused GIFs');
    expect(
      Directory('packages/home_widget/pub').existsSync(),
      isFalse,
      reason: 'F-Droid issuebot flags unused pub.dev screenshot binaries',
    );
    expect(
      File(
        'packages/home_widget/android/gradle/wrapper/gradle-wrapper.properties',
      ).existsSync(),
      isFalse,
      reason: 'Nested Gradle 8.1 wrapper is unused; F-Droid scans it',
    );
    expect(
      File('android/app/src/main/res/xml/network_security_config.xml')
          .existsSync(),
      isTrue,
    );
    final RegExp fontAsset = RegExp(r'asset:\s*(assets/fonts/\S+\.ttf)');
    for (final Match match in fontAsset.allMatches(pubspec)) {
      final String path = match.group(1)!;
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('F-Droid recipe matches the Flutter pin and buildserver constraints', () {
    final String pin =
        File('.github/flutter-version').readAsStringSync().trim();
    final String yml = File('docs/fdroid.yml').readAsStringSync();
    expect(pin, isNotEmpty);
    expect(yml, contains('flutter@$pin'));
    expect(yml, contains('NonFreeNet'));
    expect(yml, contains('opencode.ai'));
    expect(yml, contains('Remote Access'));
    expect(yml, contains('Security'));
    expect(yml, contains('pub get --enforce-lockfile'));
    expect(yml, contains('.github/flutter-version'));
    expect(yml, contains('-Xmx2G'));
    expect(yml, contains('org.gradle.daemon=false'));
    expect(yml, contains('--split-per-abi'));
    expect(yml, contains(r"'%c * 10 + 1'"));
    expect(yml, contains('VercodeOperation'));
    expect(yml, contains('app-armeabi-v7a-release.apk'));
    expect(yml, contains('app-arm64-v8a-release.apk'));
    expect(yml, contains('app-x86_64-release.apk'));
    expect(yml, contains('versionCode: 161'));
    expect(yml, contains('versionCode: 162'));
    expect(yml, contains('versionCode: 163'));
    expect(yml, contains('ndk: 28.2.13676358'));
    expect(yml, contains(r'ANDROID_NDK_HOME=$$NDK$$'));
    expect(yml, contains('newer than v1.4.1'));
    expect(
      File('android/app/build.gradle.kts').readAsStringSync(),
      contains('armeabi-v7a'),
    );
    final String releasePs = File('scripts/release.ps1').readAsStringSync();
    expect(releasePs, contains(r'10 * $build + 1'));
    expect(releasePs, contains(r'10 * $build + 2'));
    expect(releasePs, contains(r'10 * $build + 3'));
    expect(releasePs, contains('Test-FastlaneTracked'));
    expect(releasePs, contains('fastlane/metadata/android/en-US/title.txt'));
    expect(
      File('.github/workflows/release.yml').readAsStringSync(),
      contains('verify-split-apk-versioncode.sh'),
    );
    expect(
      File('.github/scripts/verify-split-apk-versioncode.sh').existsSync(),
      isTrue,
    );
  });

  test('GitHub hook scripts are LF-only for Actions bash', () {
    final List<File> scripts = Directory('.github/scripts')
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.sh'))
        .toList();
    expect(scripts, isNotEmpty);
    for (final File script in scripts) {
      expect(
        script.readAsBytesSync().contains(13),
        isFalse,
        reason: '${script.path} must be LF-only (CRLF breaks set -euo pipefail)',
      );
    }
  });
}

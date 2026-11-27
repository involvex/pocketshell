import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/constants/app_metadata.dart';
import 'package:ssh_app/models/known_host.dart';
import 'package:ssh_app/models/session_entry.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/agent_provider.dart';
import 'package:ssh_app/providers/app_lock_provider.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/providers/snippet_provider.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/screens/home_screen.dart';
import 'package:ssh_app/screens/privacy_screen.dart';
import 'package:ssh_app/screens/settings_screen.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/secure_storage.dart';
import 'package:ssh_app/services/secure_storage_service.dart';
import 'package:ssh_app/widgets/connection_modal.dart';
import 'package:ssh_app/widgets/host_key_dialog.dart';

import 'support/fdroid_screenshot_fonts.dart';

class _MemorySecureStorage implements SecureStorageBackend {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

const Key kFdroidShotKey = Key('fdroid-shot');

const String kShotDir =
    'fastlane/metadata/android/en-US/images/phoneScreenshots';

void main() {
  final bool write = Platform.environment['FDROID_SCREENSHOTS'] == '1';

  setUpAll(() async {
    if (!write) {
      return;
    }
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ssh_profiles':
          '[{"id":"demo-home","name":"Home PC","host":"192.168.1.10","port":22,"username":"user"}]',
      'app_settings':
          '{"appTheme":"dark","accentColor":"blue","terminalFontSize":16}',
    });
    await ConfigService.init();
    SecureStorageService.debugImpl = SecureStorageImpl(
      storage: _MemorySecureStorage(),
    );
    await loadFdroidScreenshotFonts();
  });

  tearDownAll(() {
    if (write) {
      SecureStorageService.debugResetImpl();
    }
  });

  testWidgets(
    'write Fastlane phone screenshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 36, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 36, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpHome(tester, ssh: _screenshotSsh(connectedSession: true));
        await tester.pump(const Duration(milliseconds: 250));
        await _pumpFrames(tester, 16);
        await _writeShot(tester, '01-client.png');

        await _pumpHarness(
          tester,
          const Scaffold(body: ConnectionModal()),
          ssh: _screenshotSsh(),
        );
        await _pumpFrames(tester);
        await _writeShot(tester, '02-connect.png');

        await _pumpHome(tester, tab: AppTab.agents);
        await _writeShot(tester, '03-agents.png');

        await _pumpHarness(tester, const SettingsScreen());
        await _pumpFrames(tester);
        await _writeShot(tester, '04-settings.png');

        await _pumpHarness(tester, const PrivacyScreen());
        await _pumpUntil(tester, find.byType(SelectableText));
        await _writeShot(tester, '05-privacy.png');

        await _pumpHarness(tester, const _HostKeyShot());
        await _pumpFrames(tester, 12);
        await _writeShot(tester, '06-host-key.png');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !write,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 30,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('never found $finder');
}

SSHProvider _screenshotSsh({bool connectedSession = false}) {
  final SSHProvider ssh = SSHProvider();
  final SSHProfile profile = SSHProfile(
    id: 'demo-home',
    name: 'Home PC',
    host: '192.168.1.10',
    username: 'user',
  );
  ssh.lastSession = profile;
  if (!connectedSession) {
    return ssh;
  }
  // Do not call createSessionFromProfile — it starts a periodic idle timer
  // that widget tests reject as a pending FakeTimer.
  const String prompt = r'PS C:\Users\user> ';
  final SessionEntry entry = SessionEntry(
    name: profile.name,
    profile: profile,
  );
  entry.isConnected = true;
  entry.touch();
  entry.terminal.write(
    'Windows PowerShell\r\n'
    'Copyright (C) Microsoft Corporation. All rights reserved.\r\n'
    '\r\n'
    '${prompt}hostname\r\n'
    'HOME-PC\r\n'
    '${prompt}Get-Date\r\n'
    'Thursday, November 26, 2026 10:32:00 PM\r\n'
    '${prompt}ssh -V\r\n'
    'OpenSSH_for_Windows_9.5p1, LibreSSL 3.8.2\r\n$prompt',
  );
  ssh.sessions.add(entry);
  ssh.activeSessionId = entry.id;
  return ssh;
}

Future<void> _pumpHome(
  WidgetTester tester, {
  AppTab tab = AppTab.client,
  SSHProvider? ssh,
}) async {
  await _pumpHarness(tester, HomeScreen(initialTab: tab), ssh: ssh);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await _pumpFrames(tester);
}

class _HostKeyShot extends StatefulWidget {
  const _HostKeyShot();

  @override
  State<_HostKeyShot> createState() => _HostKeyShotState();
}

class _HostKeyShotState extends State<_HostKeyShot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Dialog stays open for the screenshot; the future is not awaited.
      showUnknownHostKeyDialog(
        context,
        const KnownHostPrompt(
          host: '192.168.1.10',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: 'SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  Widget home, {
  SSHProvider? ssh,
}) async {
  final SSHProvider sshProvider = ssh ?? SSHProvider();
  addTearDown(sshProvider.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: kFdroidShotKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<SSHProvider>.value(
            value: sshProvider,
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider()..loadSettings(),
          ),
          ChangeNotifierProvider<AppLockProvider>(
            create: (_) => AppLockProvider()..load(),
          ),
          ChangeNotifierProvider<SnippetProvider>(
            create: (_) => SnippetProvider()..loadSnippets(),
          ),
          ChangeNotifierProxyProvider<SSHProvider, AgentProvider>(
            create: (_) => AgentProvider(),
            update: (_, ssh, AgentProvider? agent) {
              final AgentProvider provider = agent ?? AgentProvider();
              provider.onLog = ssh.addLog;
              provider.ssh = ssh;
              return provider;
            },
          ),
        ],
        child: Consumer<SettingsProvider>(
          builder: (BuildContext context, SettingsProvider settings, _) {
            return MaterialApp(
              title: kAppDisplayName,
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: settings.accentColor,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: settings.accentColor,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF1A1A2E),
                ),
                scaffoldBackgroundColor: const Color(0xFF1A1A2E),
              ),
              builder: (BuildContext context, Widget? child) {
                // ignore: deprecated_member_use
                return MaterialUiCompatibilityBridge(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: home,
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _writeShot(WidgetTester tester, String filename) async {
  await tester.pump();
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(kFdroidShotKey),
  );
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (bytes == null) {
      throw StateError('Failed to encode $filename');
    }
    final Directory dir = Directory(kShotDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    File('${dir.path}/$filename').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

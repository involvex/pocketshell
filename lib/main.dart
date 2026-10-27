import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'constants/app_metadata.dart';
import 'providers/agent_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/snippet_provider.dart';
import 'providers/ssh_provider.dart';
import 'screens/splash_screen.dart';
import 'services/app_lifecycle_service.dart';
import 'services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SSHProvider()),
        ChangeNotifierProvider(
            create: (context) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(
            create: (context) => SnippetProvider()..loadSnippets()),
        ChangeNotifierProxyProvider<SSHProvider, AgentProvider>(
          create: (context) => AgentProvider(),
          update: (context, ssh, agent) {
            final provider = agent ?? AgentProvider();
            provider.onLog = ssh.addLog;
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          // Standard light theme
          final lightTheme = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.accentColor,
              brightness: Brightness.light,
            ),
          );

          // Standard dark theme
          final darkTheme = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.accentColor,
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1A2E),
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          );

          // Custom Hacker theme (Black background, Green text)
          final hackerTheme = ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Colors.greenAccent,
              secondary: Colors.green,
              surface: Colors.black,
              onSurface: Colors.greenAccent,
              onPrimary: Colors.black,
              onSecondary: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.greenAccent,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.grey[900],
              elevation: 4,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.greenAccent, width: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            listTileTheme: const ListTileThemeData(
              iconColor: Colors.greenAccent,
              textColor: Colors.greenAccent,
            ),
          );

          return AppLifecycleHost(
            child: MaterialApp(
              title: kAppDisplayName,
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: lightTheme,
              darkTheme: settings.appTheme == AppTheme.hacker
                  ? hackerTheme
                  : darkTheme,
              builder: (context, child) {
                // Bridge ThemeData/MaterialLocalizations for packages that still
                // import package:flutter/material.dart (xterm, share_plus, etc.).
                // ignore: deprecated_member_use
                return MaterialUiCompatibilityBridge(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}

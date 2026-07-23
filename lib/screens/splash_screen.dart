import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../constants/app_metadata.dart';
import 'home_screen.dart';
import '../services/config_service.dart';
import '../services/widget_launch_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await ConfigService.init();
    final pendingLaunch = await _readPendingWidgetLaunch();
    if (pendingLaunch == null) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(pendingLaunch: pendingLaunch),
        ),
      );
    }
  }

  Future<WidgetLaunchAction?> _readPendingWidgetLaunch() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return WidgetLaunchHandler.parseUri(widgetUri);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.terminal,
                size: 64,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              kAppDisplayName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure Shell Client',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/ssh_profile.dart';
import 'config_service.dart';

/// Syncs client SSH profiles to Android home screen widgets.
class WidgetProfileService {
  static const String profilesKey = 'widget_profiles_json';
  static const String sshWidgetName =
      'com.involvex.ssh_app_flutter.SshQuickConnectWidget';
  static const String agentWidgetName =
      'com.involvex.ssh_app_flutter.AgentQuickConnectWidget';

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> syncProfiles(List<SSHProfile> profiles) async {
    if (!isSupported) {
      return;
    }

    final clientProfiles = profiles.where((p) => !p.isServer).toList();
    final payload = clientProfiles
        .map(
          (p) => <String, dynamic>{
            'id': p.id,
            'name': p.name,
            'host': p.host,
            'port': p.port,
            'agentPort': p.agentPort,
          },
        )
        .toList();

    await HomeWidget.saveWidgetData(profilesKey, jsonEncode(payload));
    await Future.wait<bool?>(<Future<bool?>>[
      HomeWidget.updateWidget(qualifiedAndroidName: sshWidgetName),
      HomeWidget.updateWidget(qualifiedAndroidName: agentWidgetName),
    ]);
  }

  static Future<void> syncFromConfig() async {
    if (!isSupported) {
      return;
    }

    final profileData = await ConfigService.getProfiles();
    final profiles =
        profileData.map((e) => SSHProfile.fromJson(e)).toList(growable: false);
    await syncProfiles(profiles);
  }
}

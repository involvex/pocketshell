import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ssh_profile.dart';
import '../providers/agent_provider.dart';
import '../providers/ssh_provider.dart';
import '../screens/home_screen.dart';

enum WidgetLaunchKind { ssh, agent }

class WidgetLaunchAction {
  const WidgetLaunchAction({
    required this.kind,
    required this.profileId,
  });

  final WidgetLaunchKind kind;
  final String profileId;
}

class WidgetLaunchHandler {
  static WidgetLaunchAction? parseUri(Uri? uri) {
    if (uri == null) {
      return null;
    }
    if (uri.scheme != 'sshapp' || uri.host != 'widget') {
      return null;
    }

    final profileId = uri.queryParameters['profileId'];
    if (profileId == null || profileId.isEmpty) {
      return null;
    }

    final path = uri.path;
    if (path == '/ssh' || path == 'ssh') {
      return WidgetLaunchAction(
        kind: WidgetLaunchKind.ssh,
        profileId: profileId,
      );
    }
    if (path == '/agent' || path == 'agent') {
      return WidgetLaunchAction(
        kind: WidgetLaunchKind.agent,
        profileId: profileId,
      );
    }
    return null;
  }

  static Future<void> execute(
    BuildContext context,
    WidgetLaunchAction action, {
    void Function(AppTab tab)? onTabSelected,
  }) async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final agent = Provider.of<AgentProvider>(context, listen: false);

    SSHProfile? profile;
    for (final p in ssh.profiles) {
      if (p.id == action.profileId) {
        profile = p;
        break;
      }
    }

    if (profile == null || profile.isServer) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      switch (action.kind) {
        case WidgetLaunchKind.ssh:
          final entry =
              ssh.createSessionFromProfile(profile, name: profile.name);
          await ssh.connectSession(entry.id);
          onTabSelected?.call(AppTab.client);
        case WidgetLaunchKind.agent:
          await agent.connectFromProfileAndOpenRecent(profile);
          onTabSelected?.call(AppTab.agents);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

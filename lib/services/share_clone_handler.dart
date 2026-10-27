import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/session_entry.dart';
import '../models/ssh_profile.dart';
import '../providers/ssh_provider.dart';
import '../screens/home_screen.dart';
import 'share_intent_service.dart';

/// Connects the last-used SSH profile and pastes `git clone <url>`.
class ShareCloneHandler {
  const ShareCloneHandler._();

  static Future<void> execute(
    BuildContext context,
    String sharedText, {
    void Function(AppTab tab)? onTabSelected,
  }) async {
    final String? url = ShareIntentService.parseGitUrl(sharedText);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No git URL found in shared text'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final SSHProvider ssh = Provider.of<SSHProvider>(context, listen: false);
    final List<SSHProfile> candidates = clientProfiles(ssh);
    if (candidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create an SSH profile first, then share again'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final SSHProfile? def = resolveShareProfile(ssh);
    final SSHProfile profile;
    if (candidates.length == 1) {
      profile = candidates.first;
    } else {
      if (!context.mounted) {
        return;
      }
      final SSHProfile? picked = await showShareProfilePicker(
        context,
        candidates,
        initial: def,
        gitUrl: url,
      );
      if (picked == null) {
        return;
      }
      profile = picked;
    }

    onTabSelected?.call(AppTab.client);

    final String command = ShareIntentService.buildGitCloneCommand(url);

    try {
      final bool alreadyOnProfile = ssh.activeSession != null &&
          ssh.activeSession!.isConnected &&
          ssh.activeSession!.profile.id == profile.id;

      if (!alreadyOnProfile) {
        SessionEntry? existing;
        for (final SessionEntry s in ssh.sessions) {
          if (s.profile.id == profile.id && s.isConnected) {
            existing = s;
            break;
          }
        }
        if (existing != null) {
          ssh.switchActiveSession(existing.id);
        } else {
          final SessionEntry entry =
              ssh.createSessionFromProfile(profile, name: profile.name);
          await ssh.connectSession(entry.id);
          await ssh.saveLastSession(profile);
        }
      }

      if (!context.mounted) {
        return;
      }

      final active = ssh.activeSession;
      if (active == null || !active.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect for git clone'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Paste only — no Enter — so the user can edit the command first.
      ssh.sendString(command);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ready: $command')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share clone failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Bottom sheet listing client profiles so a share can target a host
  /// other than the last-connected one. Returns the chosen profile, or
  /// null when the sheet is dismissed.
  static Future<SSHProfile?> showShareProfilePicker(
    BuildContext context,
    List<SSHProfile> candidates, {
    required String gitUrl,
    SSHProfile? initial,
  }) {
    SSHProfile selected = initial != null &&
            candidates.any((SSHProfile p) => p.id == initial.id)
        ? candidates.firstWhere((SSHProfile p) => p.id == initial.id)
        : candidates.first;
    return showModalBottomSheet<SSHProfile>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Clone to host',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'git clone $gitUrl',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SSHProfile p = candidates[index];
                          final bool isLast =
                              initial != null && p.id == initial.id;
                          final bool isSelected = p.id == selected.id;
                          return ListTile(
                            leading: const Icon(Icons.computer),
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.username}@${p.host}:${p.port}'
                              '${isLast ? ' · last connected' : ''}',
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.circle_outlined),
                            selected: isSelected,
                            onTap: () {
                              setState(() => selected = p);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, selected),
                            child: const Text('Clone here'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// All non-server profiles eligible as a share-clone target.
  static List<SSHProfile> clientProfiles(SSHProvider ssh) =>
      ssh.profiles.where((SSHProfile p) => !p.isServer).toList();

  /// Prefer last connected session, else first non-server saved profile.
  static SSHProfile? resolveShareProfile(SSHProvider ssh) {
    final SSHProfile? last = ssh.lastSession;
    if (last != null && !last.isServer) {
      // Prefer the live profile from the list (freshest credentials).
      for (final SSHProfile p in ssh.profiles) {
        if (p.id == last.id && !p.isServer) {
          return p;
        }
      }
      return last;
    }
    for (final SSHProfile p in ssh.profiles) {
      if (!p.isServer) {
        return p;
      }
    }
    return null;
  }
}

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/session_entry.dart';
import '../models/ssh_profile.dart';
import '../providers/ssh_provider.dart';
import '../screens/home_screen.dart';
import '../widgets/sftp_browser.dart';
import 'share_clone_handler.dart';
import 'share_intent_service.dart';

/// Uploads Android-shared files to a connected host over SFTP.
class ShareUploadHandler {
  const ShareUploadHandler._();

  /// Opens SFTP for [sessionId] and uploads [files] into the current directory.
  static Future<void> execute(
    BuildContext context,
    List<SharedFile> files, {
    void Function(AppTab tab)? onTabSelected,
    Future<void> Function(
      BuildContext context,
      String sessionId,
      List<SharedFile> files,
    )? openSftpUpload,
  }) async {
    if (files.isEmpty) {
      return;
    }

    final SSHProvider ssh = Provider.of<SSHProvider>(context, listen: false);
    final List<SessionEntry> connected = connectedSessions(ssh);

    onTabSelected?.call(AppTab.client);

    if (connected.isNotEmpty) {
      final SessionEntry session;
      if (connected.length == 1) {
        session = connected.first;
      } else {
        if (!context.mounted) {
          return;
        }
        final SessionEntry? picked = await showShareSessionPicker(
          context,
          connected,
          files: files,
          initial: resolveUploadSession(ssh),
        );
        if (picked == null) {
          return;
        }
        session = picked;
      }

      if (ssh.activeSessionId != session.id) {
        ssh.switchActiveSession(session.id);
      }

      if (!context.mounted) {
        return;
      }
      final Future<void> Function(
        BuildContext context,
        String sessionId,
        List<SharedFile> files,
      ) open = openSftpUpload ?? _defaultOpenSftpUpload;
      await open(context, session.id, files);
      return;
    }

    // No live session — require an explicit profile pick, then connect.
    final List<SSHProfile> candidates = ShareCloneHandler.clientProfiles(ssh);
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

    if (!context.mounted) {
      return;
    }
    final SSHProfile? profile = await showShareUploadProfilePicker(
      context,
      candidates,
      files: files,
      initial: ShareCloneHandler.resolveShareProfile(ssh),
    );
    if (profile == null) {
      return;
    }

    try {
      SessionEntry? existing;
      for (final SessionEntry s in ssh.sessions) {
        if (s.profile.id == profile.id && s.isConnected) {
          existing = s;
          break;
        }
      }
      final SessionEntry session;
      if (existing != null) {
        ssh.switchActiveSession(existing.id);
        session = existing;
      } else {
        final SessionEntry entry =
            ssh.createSessionFromProfile(profile, name: profile.name);
        await ssh.connectSession(entry.id);
        await ssh.saveLastSession(profile);
        session = entry;
      }

      if (!context.mounted) {
        return;
      }
      if (!session.isConnected || session.client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect for file upload'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final Future<void> Function(
        BuildContext context,
        String sessionId,
        List<SharedFile> files,
      ) open = openSftpUpload ?? _defaultOpenSftpUpload;
      await open(context, session.id, files);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Connected sessions that can accept an SFTP upload.
  static List<SessionEntry> connectedSessions(SSHProvider ssh) => ssh.sessions
      .where((SessionEntry s) => s.isConnected && s.client != null)
      .toList();

  /// Prefer the active connected session, else the first connected one.
  static SessionEntry? resolveUploadSession(SSHProvider ssh) {
    final SessionEntry? active = ssh.activeSession;
    if (active != null && active.isConnected && active.client != null) {
      return active;
    }
    final List<SessionEntry> connected = connectedSessions(ssh);
    if (connected.isEmpty) {
      return null;
    }
    return connected.first;
  }

  /// True when files should be uploaded (connected session available).
  ///
  /// Used by hermetic tests; UI still prompts to connect when false.
  static bool canUploadWithoutConnect(SSHProvider ssh) =>
      connectedSessions(ssh).isNotEmpty;

  static Future<void> _defaultOpenSftpUpload(
    BuildContext context,
    String sessionId,
    List<SharedFile> files,
  ) async {
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('SFTP')),
          body: SftpBrowser(
            sessionId: sessionId,
            pendingUploads: files,
          ),
        ),
      ),
    );
  }

  static Future<SessionEntry?> showShareSessionPicker(
    BuildContext context,
    List<SessionEntry> candidates, {
    required List<SharedFile> files,
    SessionEntry? initial,
  }) {
    SessionEntry selected = initial != null &&
            candidates.any((SessionEntry s) => s.id == initial.id)
        ? candidates.firstWhere((SessionEntry s) => s.id == initial.id)
        : candidates.first;
    final String subtitle = _fileSummary(files);
    return showModalBottomSheet<SessionEntry>(
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
                      'Upload to session',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
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
                          final SessionEntry s = candidates[index];
                          final bool isActive =
                              initial != null && s.id == initial.id;
                          final bool isSelected = s.id == selected.id;
                          return ListTile(
                            leading: const Icon(Icons.terminal),
                            title: Text(s.name),
                            subtitle: Text(
                              '${s.profile.username}@${s.profile.host}'
                              '${isActive ? ' · active' : ''}',
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.circle_outlined),
                            selected: isSelected,
                            onTap: () {
                              setState(() => selected = s);
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
                            child: const Text('Upload here'),
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

  static Future<SSHProfile?> showShareUploadProfilePicker(
    BuildContext context,
    List<SSHProfile> candidates, {
    required List<SharedFile> files,
    SSHProfile? initial,
  }) {
    SSHProfile selected = initial != null &&
            candidates.any((SSHProfile p) => p.id == initial.id)
        ? candidates.firstWhere((SSHProfile p) => p.id == initial.id)
        : candidates.first;
    final String subtitle = _fileSummary(files);
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
                      'Upload to host',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connects the chosen profile, then opens SFTP.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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
                            child: const Text('Connect & upload'),
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

  static String _fileSummary(List<SharedFile> files) {
    if (files.length == 1) {
      return files.first.name;
    }
    return '${files.length} files';
  }

  /// Builds [File] handles for enqueueing uploads with display names.
  static List<({File file, String remoteName})> uploadItems(
    List<SharedFile> files,
  ) {
    return <({File file, String remoteName})>[
      for (final SharedFile f in files)
        (file: File(f.path), remoteName: f.name),
    ];
  }
}

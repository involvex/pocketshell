import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart';
import 'package:provider/provider.dart';

import '../../models/agent_connection.dart';
import '../../providers/agent_provider.dart';
import '../../utils/agent_session_utils.dart';
import 'agent_directory_bar.dart';

/// Session list view for an agent connection.
class AgentSessionList extends StatelessWidget {
  const AgentSessionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentProvider>(
      builder: (context, agents, child) {
        final active = agents.activeConnection;
        if (active == null) return const SizedBox.shrink();

        final hasDirectory = active.selectedDirectory != null &&
            active.selectedDirectory!.isNotEmpty;
        final showDirectoryPrompt = active.isLocal && !hasDirectory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AgentDirectoryBar(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sessions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'New session',
                    onPressed: () => _createSession(context, agents, active),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () => agents.refreshSessions(active.id),
                  ),
                ],
              ),
            ),
            Expanded(
              child: showDirectoryPrompt
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Select a project directory via SFTP to view sessions.\n'
                          'Connect an SSH session to the agent host first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : active.sessions.isEmpty
                      ? const Center(
                          child: Text(
                              'No sessions yet. Create one to get started.'),
                        )
                      : ListView.builder(
                          itemCount: active.sessions.length,
                          itemBuilder: (context, index) {
                            final session = active.sessions[index];
                            final isActive =
                                active.activeSessionId == session.id;
                            return ListTile(
                              dense: true,
                              selected: isActive,
                              title: Text(
                                session.title ?? session.id ?? 'Untitled',
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _sessionSubtitle(session),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: session.id == null
                                    ? null
                                    : () => agents.deleteSession(
                                          active.id,
                                          session.id!,
                                        ),
                              ),
                              onTap: session.id == null
                                  ? null
                                  : () => agents.selectSession(
                                        active.id,
                                        session.id!,
                                      ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  String _sessionSubtitle(Session session) {
    final parts = <String>[];
    final timestamp = formatSessionTimestamp(
      session.time?.updated ?? session.time?.created,
    );
    if (timestamp.isNotEmpty) {
      parts.add(timestamp);
    }
    if (session.directory != null && session.directory!.isNotEmpty) {
      parts.add(session.directory!);
    } else if (session.id != null) {
      parts.add(session.id!);
    }
    return parts.join(' · ');
  }

  Future<void> _createSession(
    BuildContext context,
    AgentProvider agents,
    AgentConnection connection,
  ) async {
    if (connection.isLocal &&
        (connection.selectedDirectory == null ||
            connection.selectedDirectory!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a project directory via SFTP before creating a session',
          ),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final title = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Session'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title (optional)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = titleController.text.trim();
              Navigator.pop(dialogContext, value.isEmpty ? null : value);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    titleController.dispose();

    if (!context.mounted) return;
    await agents.createSession(connection.id, title: title);
  }
}

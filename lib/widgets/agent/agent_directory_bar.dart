import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/agent_connection.dart';
import '../../providers/agent_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/sftp_directory_picker.dart';

/// Directory picker bar for agent connections.
class AgentDirectoryBar extends StatelessWidget {
  const AgentDirectoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AgentProvider, SSHProvider>(
      builder: (context, agents, ssh, child) {
        final active = agents.activeConnection;
        if (active == null) return const SizedBox.shrink();

        final directory = active.selectedDirectory;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Card(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                directory ?? 'No directory selected',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: directory == null
                      ? Theme.of(context).colorScheme.outline
                      : null,
                ),
              ),
              subtitle: const Text(
                'Browse via SFTP',
                style: TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: 'Select project directory via SFTP',
                onPressed: () => _pickDirectory(context, agents, active, ssh),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDirectory(
    BuildContext context,
    AgentProvider agents,
    AgentConnection connection,
    SSHProvider ssh,
  ) async {
    final sshSession = ssh.findConnectedSessionForHost(connection.profile.host);

    if (sshSession?.client == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connect an SSH session to ${connection.profile.host} first, '
            'then pick a directory via SFTP.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SftpDirectoryPicker(
        client: sshSession!.client!,
        initialPath: connection.selectedDirectory,
      ),
    );

    if (picked == null || !context.mounted) return;
    await agents.setDirectory(connection.id, picked);
  }
}

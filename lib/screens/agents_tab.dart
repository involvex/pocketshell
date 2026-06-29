import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart' show MessageWithParts, Session;
import 'package:provider/provider.dart';

import '../models/agent_connection.dart';
import '../models/ssh_profile.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../utils/agent_session_utils.dart';
import '../widgets/agent_permission_dialog.dart';
import '../widgets/agent_model_provider_sheet.dart';
import '../widgets/agent_prompt_input.dart';
import '../widgets/sftp_directory_picker.dart';

class AgentsTab extends StatefulWidget {
  const AgentsTab({super.key});

  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab> {
  final TextEditingController _manualUrlController = TextEditingController();
  final TextEditingController _manualPasswordController =
      TextEditingController();
  final TextEditingController _localPasswordController =
      TextEditingController();
  bool _isConnecting = false;
  bool _permissionDialogVisible = false;

  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void dispose() {
    _manualUrlController.dispose();
    _manualPasswordController.dispose();
    _localPasswordController.dispose();
    super.dispose();
  }

  Future<void> _connectProfile(SSHProfile profile) async {
    setState(() => _isConnecting = true);
    try {
      await Provider.of<AgentProvider>(context, listen: false)
          .connectFromProfile(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connect failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectLocalDesktop(int port) async {
    setState(() => _isConnecting = true);
    try {
      await Provider.of<AgentProvider>(context, listen: false)
          .connectToLocalDesktop(
        port: port,
        password: _localPasswordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Local connect failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectManualUrl() async {
    final url = _manualUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isConnecting = true);
    try {
      await Provider.of<AgentProvider>(context, listen: false).connectFromUrl(
        url: url.startsWith('http') ? url : 'http://$url',
        password: _manualPasswordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connect failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _pickDirectory(
    AgentProvider agents,
    AgentConnection connection,
  ) async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final sshSession = ssh.findConnectedSessionForHost(connection.profile.host);

    if (sshSession?.client == null) {
      if (!mounted) return;
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

    if (picked == null || !mounted) return;
    await agents.setDirectory(connection.id, picked);
  }

  Future<void> _createSession(
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

    if (!mounted) return;
    await agents.createSession(connection.id, title: title);
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

  @override
  Widget build(BuildContext context) {
    return Consumer3<AgentProvider, SSHProvider, SettingsProvider>(
      builder: (context, agents, ssh, settings, child) {
        if (agents.pendingPermission != null && !_permissionDialogVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPermissionDialog(context, agents);
          });
        }

        if (agents.connections.isEmpty) {
          return _buildDisconnectedView(
              ssh.profiles, settings.defaultAgentPort);
        }

        final active = agents.activeConnection;
        if (active == null) {
          return const Center(child: Text('No active agent connection'));
        }

        final showingChat = active.activeSessionId != null;

        return PopScope(
          canPop: !showingChat,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && showingChat) {
              agents.clearActiveSession(active.id);
            }
          },
          child: Column(
            children: [
              _buildConnectionBar(agents),
              Expanded(
                child: showingChat
                    ? _buildChatPane(agents, active)
                    : _buildSessionList(agents, active),
              ),
              if (showingChat) _buildPromptInput(agents, active),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedView(List<SSHProfile> profiles, int agentPort) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Connect to OpenCode Agent',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Attach to a running opencode web/serve instance using saved profiles.',
        ),
        const SizedBox(height: 16),
        if (_isConnecting) const LinearProgressIndicator(),
        if (_isDesktopPlatform) ...[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.computer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              title: const Text('Local OpenCode (Desktop)'),
              subtitle: Text(
                'Connect to opencode serve on 127.0.0.1:$agentPort',
              ),
              trailing: const Icon(Icons.link),
              onTap:
                  _isConnecting ? null : () => _connectLocalDesktop(agentPort),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: TextField(
              controller: _localPasswordController,
              decoration: const InputDecoration(
                labelText: 'Local password (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              obscureText: true,
            ),
          ),
          const Divider(height: 32),
        ],
        if (profiles.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No profiles saved'),
              subtitle: Text('Add a profile with host and agent port first'),
            ),
          )
        else
          ...profiles.map(
            (profile) => Card(
              child: ListTile(
                leading: const Icon(Icons.smart_toy, color: Colors.purple),
                title: Text(profile.name),
                subtitle: Text(
                  'SSH ${profile.host}:${profile.port} · Agent ${profile.agentBaseUrl}',
                ),
                trailing: const Icon(Icons.link),
                onTap: _isConnecting ? null : () => _connectProfile(profile),
              ),
            ),
          ),
        const Divider(height: 32),
        const Text(
          'Manual URL',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _manualUrlController,
          decoration: const InputDecoration(
            labelText: 'OpenCode URL',
            hintText: 'http://involvex.myfritz.link:5000',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _manualPasswordController,
          decoration: const InputDecoration(
            labelText: 'Password (optional)',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isConnecting ? null : _connectManualUrl,
          icon: const Icon(Icons.link),
          label: const Text('Connect'),
        ),
      ],
    );
  }

  Widget _buildConnectionBar(AgentProvider agents) {
    final chips = agents.connections.map((connection) {
      final isActive = agents.activeConnectionId == connection.id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InputChip(
          selected: isActive,
          avatar: CircleAvatar(
            radius: 4,
            backgroundColor: connection.isConnected ? Colors.green : Colors.red,
          ),
          label: Text(connection.profile.name),
          onPressed: () => agents.switchActiveConnection(connection.id),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () => agents.disconnect(connection.id),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  Widget _buildDirectoryBar(AgentProvider agents, AgentConnection connection) {
    final directory = connection.selectedDirectory;
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
            onPressed: () => _pickDirectory(agents, connection),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(AgentProvider agents, AgentConnection connection) {
    final hasDirectory = connection.selectedDirectory != null &&
        connection.selectedDirectory!.isNotEmpty;
    final showDirectoryPrompt = connection.isLocal && !hasDirectory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDirectoryBar(agents, connection),
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
                onPressed: () => _createSession(agents, connection),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => agents.refreshSessions(connection.id),
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
              : connection.sessions.isEmpty
                  ? const Center(
                      child:
                          Text('No sessions yet. Create one to get started.'),
                    )
                  : ListView.builder(
                      itemCount: connection.sessions.length,
                      itemBuilder: (context, index) {
                        final session = connection.sessions[index];
                        final isActive =
                            connection.activeSessionId == session.id;
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
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: session.id == null
                                ? null
                                : () => agents.deleteSession(
                                      connection.id,
                                      session.id!,
                                    ),
                          ),
                          onTap: session.id == null
                              ? null
                              : () => agents.selectSession(
                                    connection.id,
                                    session.id!,
                                  ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChatPane(AgentProvider agents, AgentConnection active) {
    final sessionId = active.activeSessionId!;
    String title = sessionId;
    for (final session in active.sessions) {
      if (session.id == sessionId) {
        title = session.title ?? sessionId;
        break;
      }
    }

    final currentModel = agents.currentModelId(active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 1,
          child: ListTile(
            dense: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to sessions',
              onPressed: () => agents.clearActiveSession(active.id),
            ),
            title: Text(
              title,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: currentModel == null
                ? null
                : Text(
                    currentModel,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Model & providers',
              onPressed: () => showAgentModelProviderSheet(context, active),
            ),
          ),
        ),
        Expanded(child: _buildChatView(agents, active)),
      ],
    );
  }

  Widget _buildChatView(AgentProvider agents, AgentConnection active) {
    if (active.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (active.messages.isEmpty) {
      return const Center(child: Text('No messages yet. Send a prompt below.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: active.messages.length,
      itemBuilder: (context, index) {
        final message = active.messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildPromptInput(AgentProvider agents, AgentConnection active) {
    final canSend = active.activeSessionId != null;

    return AgentPromptInput(
      commands: active.availableCommands,
      agents: active.availableAgents,
      models: active.modelOptions,
      enabled: canSend,
      isSending: active.isSending,
      onSubmit: (text) => agents.sendPrompt(active.id, text),
    );
  }

  Future<void> _showPermissionDialog(
    BuildContext context,
    AgentProvider agents,
  ) async {
    final pending = agents.pendingPermission;
    if (pending == null || _permissionDialogVisible) return;

    _permissionDialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AgentPermissionDialog(
        request: pending,
        onRespond: (response, remember) async {
          await agents.respondToPermission(
            response: response,
            remember: remember,
          );
        },
        onDismiss: agents.dismissPermission,
      ),
    );
    _permissionDialogVisible = false;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MessageWithParts message;

  @override
  Widget build(BuildContext context) {
    final role = message.info?.role ?? 'unknown';
    final isUser = role == 'user';
    final parts = message.parts ?? [];

    final textParts = parts
        .where((p) => p.type == 'text' || p.text != null)
        .map((p) => p.text ?? p.content ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n');

    final toolParts = parts.where((p) => p.type != 'text' && p.text == null);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (textParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(textParts),
            ],
            for (final part in toolParts)
              ExpansionTile(
                title: Text('[${part.type ?? 'tool'}]'),
                children: [
                  SelectableText(part.content ?? part.text ?? ''),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

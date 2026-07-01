import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart' show Session;
import 'package:provider/provider.dart';

import '../models/agent_connection.dart';
import '../models/ssh_profile.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../utils/agent_message_grouping.dart';
import '../utils/agent_session_utils.dart';
import '../widgets/agent_message_bubble.dart';
import '../widgets/agent_permission_dialog.dart';
import '../widgets/agent_model_provider_sheet.dart';
import '../widgets/agent_prompt_input.dart';
import '../widgets/opencode_config_sheet.dart';
import '../widgets/sftp_directory_picker.dart';

class AgentsTab extends StatefulWidget {
  const AgentsTab({this.onChatOpenChanged, super.key});

  final ValueChanged<bool>? onChatOpenChanged;

  @override
  State<AgentsTab> createState() => AgentsTabState();
}

class AgentsTabState extends State<AgentsTab> {
  final TextEditingController _manualUrlController = TextEditingController();
  final TextEditingController _manualPasswordController =
      TextEditingController();
  final TextEditingController _localPasswordController =
      TextEditingController();
  bool _isConnecting = false;
  bool _permissionDialogVisible = false;

  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  void handleBack() {
    final agents = Provider.of<AgentProvider>(context, listen: false);
    final active = agents.activeConnection;
    if (active?.activeSessionId != null) {
      agents.clearActiveSession(active!.id);
    }
  }

  @override
  void dispose() {
    _manualUrlController.dispose();
    _manualPasswordController.dispose();
    _localPasswordController.dispose();
    super.dispose();
  }

  void _notifyChatOpen(bool open) {
    widget.onChatOpenChanged?.call(open);
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
          _notifyChatOpen(false);
          return _buildDisconnectedView(
              ssh.profiles, settings.defaultAgentPort);
        }

        final active = agents.activeConnection;
        if (active == null) {
          _notifyChatOpen(false);
          return const Center(child: Text('No active agent connection'));
        }

        final showingChat = active.activeSessionId != null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyChatOpen(showingChat);
        });

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to sessions',
                  onPressed: () => agents.clearActiveSession(active.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (currentModel != null)
                        Text(
                          currentModel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    active.collapseToolParts
                        ? Icons.unfold_more
                        : Icons.unfold_less,
                  ),
                  tooltip: active.collapseToolParts
                      ? 'Expand tool parts'
                      : 'Collapse tool parts',
                  onPressed: () =>
                      agents.toggleCollapseToolParts(active.id),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Chat options',
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'config',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('OpenCode config'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'model',
                      child: ListTile(
                        leading: Icon(Icons.tune),
                        title: Text('Model & providers'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'config':
                        showOpenCodeConfigSheet(context, active);
                      case 'model':
                        showAgentModelProviderSheet(context, active);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _AgentChatScrollView(
            key: ValueKey<String>(sessionId),
            connection: active,
          ),
        ),
      ],
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

class _AgentChatScrollView extends StatefulWidget {
  const _AgentChatScrollView({required this.connection, super.key});

  final AgentConnection connection;

  @override
  State<_AgentChatScrollView> createState() => _AgentChatScrollViewState();
}

class _AgentChatScrollViewState extends State<_AgentChatScrollView> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _wasSending = false;
  bool _showScrollTop = false;
  bool _showScrollBottom = false;

  static const double _nearEdgeThreshold = 80;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.connection.messages.length;
    _wasSending = widget.connection.isSending;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atTop = position.pixels <= _nearEdgeThreshold;
    final atBottom = position.pixels >=
        position.maxScrollExtent - _nearEdgeThreshold;
    if (atTop != !_showScrollTop || atBottom != !_showScrollBottom) {
      setState(() {
        _showScrollTop = !atTop;
        _showScrollBottom = !atBottom && position.maxScrollExtent > 0;
      });
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >=
        position.maxScrollExtent - _nearEdgeThreshold;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;

    if (connection.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (connection.messages.isEmpty) {
      return const Center(
        child: Text('No messages yet. Send a prompt below.'),
      );
    }

    final messageCount = connection.messages.length;
    final isSending = connection.isSending;
    if (messageCount > _lastMessageCount ||
        (isSending != _wasSending && isSending)) {
      final shouldAutoScroll = _isNearBottom();
      _lastMessageCount = messageCount;
      _wasSending = isSending;
      if (shouldAutoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
          _onScroll();
        });
      }
    }

    final groups = groupAgentMessages(connection.messages);

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return AgentMessageGroupBubble(
              group: group,
              collapseToolParts: connection.collapseToolParts,
            );
          },
        ),
        if (_showScrollTop)
          Positioned(
            right: 8,
            bottom: 52,
            child: _ScrollFab(
              icon: Icons.arrow_upward,
              tooltip: 'Scroll to top',
              onPressed: _scrollToTop,
              heroTag: 'agent_scroll_top',
            ),
          ),
        if (_showScrollBottom)
          Positioned(
            right: 8,
            bottom: 8,
            child: _ScrollFab(
              icon: Icons.arrow_downward,
              tooltip: 'Scroll to bottom',
              onPressed: _scrollToBottom,
              heroTag: 'agent_scroll_bottom',
            ),
          ),
      ],
    );
  }
}

class _ScrollFab extends StatelessWidget {
  const _ScrollFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.heroTag,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}

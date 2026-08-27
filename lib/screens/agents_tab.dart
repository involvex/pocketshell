import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agent_connection.dart';
import '../models/ssh_profile.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../widgets/agent/agent_chat_pane.dart';
import '../widgets/agent/agent_connection_bar.dart';
import '../widgets/agent/agent_session_list.dart';
import '../widgets/agent_permission_dialog.dart';
import '../widgets/agent_prompt_input.dart';

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
              const AgentConnectionBar(),
              Expanded(
                child: showingChat
                    ? AgentChatPane(agents: agents, active: active)
                    : const AgentSessionList(),
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

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/agent_connection.dart';
import '../../models/agent_prompt_attachment.dart';
import '../../providers/agent_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../utils/agent_message_grouping.dart';
import '../../widgets/agent_message_bubble.dart';
import '../../widgets/agent_model_provider_sheet.dart';
import '../../widgets/agent_prompt_input.dart';
import '../../widgets/opencode_config_sheet.dart';
import '../../widgets/sftp_file_picker.dart';
import 'agent_scroll_fab.dart';

/// Chat pane showing messages and prompt input for an active agent session.
class AgentChatPane extends StatelessWidget {
  const AgentChatPane({
    required this.agents,
    required this.active,
    super.key,
  });

  final AgentProvider agents;
  final AgentConnection active;

  @override
  Widget build(BuildContext context) {
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
        _buildChatHeader(context, title, currentModel),
        Expanded(
          child: _AgentChatScrollView(
            key: ValueKey<String>(sessionId),
            agents: agents,
            connection: active,
          ),
        ),
        if (active.hasSessionUsage) _UsageFooter(connection: active),
        _buildPromptInput(context),
      ],
    );
  }

  Widget _buildChatHeader(
    BuildContext context,
    String title,
    String? currentModel,
  ) {
    return Material(
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
              onPressed: () => agents.toggleCollapseToolParts(active.id),
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
    );
  }

  Future<AgentPromptAttachment?> _pickRemoteFile(BuildContext context) async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final session = ssh.findConnectedSessionForHost(active.profile.host);
    if (session?.client == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connect SSH to ${active.profile.host} to pick a remote file.',
            ),
          ),
        );
      }
      return null;
    }

    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SftpFilePicker(
        client: session!.client!,
        initialPath: active.selectedDirectory,
      ),
    );
    if (path == null || path.isEmpty) return null;
    return AgentPromptAttachment.remotePath(path);
  }

  Widget _buildPromptInput(BuildContext context) {
    final canSend = active.activeSessionId != null;
    final ssh = Provider.of<SSHProvider>(context);
    final hasSsh =
        ssh.findConnectedSessionForHost(active.profile.host)?.client != null;

    return AgentPromptInput(
      commands: active.availableCommands,
      agents: active.availableAgents,
      models: active.modelOptions,
      enabled: canSend,
      isSending: active.isSending,
      onPickRemoteFile:
          hasSsh ? () => _pickRemoteFile(context) : null,
      onSubmit: (submission) => agents.sendPrompt(
        active.id,
        submission.text,
        attachments: submission.attachments,
      ),
    );
  }
}

class _UsageFooter extends StatelessWidget {
  const _UsageFooter({required this.connection});

  final AgentConnection connection;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    final parts = <String>[];
    if (connection.sessionInputTokens > 0 ||
        connection.sessionOutputTokens > 0) {
      parts.add(
        'Tokens in ${connection.sessionInputTokens} · out ${connection.sessionOutputTokens}',
      );
    }
    final cost = connection.sessionCost;
    if (cost != null && cost > 0) {
      parts.add('Cost \$${cost.toStringAsFixed(4)}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(parts.join(' · '), style: style),
      ),
    );
  }
}

/// Internal scroll view for agent chat messages.
class _AgentChatScrollView extends StatefulWidget {
  const _AgentChatScrollView({
    required this.agents,
    required this.connection,
    super.key,
  });

  final AgentProvider agents;
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
    final atBottom =
        position.pixels >= position.maxScrollExtent - _nearEdgeThreshold;
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
    return position.pixels >= position.maxScrollExtent - _nearEdgeThreshold;
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

  Future<void> _revertPart(String messageId, String? partId) async {
    try {
      await widget.agents.revertMessagePart(
        widget.connection.id,
        messageId,
        partId: partId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revert failed: $e')),
      );
    }
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
              onRevertPart: _revertPart,
            );
          },
        ),
        if (_showScrollTop)
          Positioned(
            right: 8,
            bottom: 52,
            child: AgentScrollFab(
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
            child: AgentScrollFab(
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
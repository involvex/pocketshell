import 'package:material_ui/material_ui.dart';
import 'package:opencode_api/opencode_api.dart';

import '../services/opencode_v2_mappers.dart';
import '../utils/agent_message_grouping.dart';
import 'agent_message_part_tile.dart';

typedef AgentMessageRevertCallback = Future<void> Function(
  String messageId,
  String? partId,
);

class AgentMessageGroupBubble extends StatelessWidget {
  const AgentMessageGroupBubble({
    required this.group,
    this.collapseToolParts = true,
    this.onRevertPart,
    super.key,
  });

  final AgentMessageGroup group;
  final bool collapseToolParts;
  final AgentMessageRevertCallback? onRevertPart;

  static bool _hasExpandableActivity(
    List<({MessagePart part, String? messageId})> parts,
  ) {
    return parts.any((entry) {
      final body = (entry.part.text ?? entry.part.content ?? '').trim();
      return body.isNotEmpty;
    });
  }

  List<({MessagePart part, String? messageId})> _entries() {
    final entries = <({MessagePart part, String? messageId})>[];
    for (final message in group.messages) {
      final messageId = message.info?.id;
      for (final part in message.parts ?? <MessagePart>[]) {
        if (!isRenderablePart(part)) continue;
        entries.add((part: part, messageId: messageId));
      }
    }
    return entries;
  }

  Widget _partTile({
    required MessagePart part,
    required String? messageId,
    required bool isUser,
  }) {
    final body = part.text ?? part.content ?? '';
    final canRevert = !isUser &&
        onRevertPart != null &&
        messageId != null &&
        looksLikeUnifiedDiff(body);

    return AgentMessagePartTile(
      part: part,
      forceCollapsed: collapseToolParts,
      compact: true,
      canRevert: canRevert,
      onRevert: canRevert
          ? () => onRevertPart!(messageId, part.id)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = group.role;
    final isUser = role == 'user';
    final entries = _entries();
    if (entries.isEmpty) return const SizedBox.shrink();

    final textEntries =
        entries.where((e) => isTextPart(e.part)).toList(growable: false);
    final activityEntries =
        entries.where((e) => !isTextPart(e.part)).toList(growable: false);

    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isUser ? width * 0.88 : width - 16,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isUser ? 12 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 12),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.18),
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoleChip(role: role, isUser: isUser),
                  if (textEntries.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    for (final entry in textEntries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _partTile(
                          part: entry.part,
                          messageId: entry.messageId,
                          isUser: isUser,
                        ),
                      ),
                  ],
                  if (activityEntries.isNotEmpty) ...[
                    if (textEntries.isNotEmpty) const SizedBox(height: 4),
                    if (_hasExpandableActivity(activityEntries) ||
                        activityEntries.length > 3)
                      _ActivitySection(
                        entries: activityEntries,
                        collapseToolParts: collapseToolParts,
                        isUser: isUser,
                        onRevertPart: onRevertPart,
                      )
                    else
                      for (final entry in activityEntries)
                        _partTile(
                          part: entry.part,
                          messageId: entry.messageId,
                          isUser: isUser,
                        ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.isUser});

  final String role;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'user' => 'You',
      'assistant' => 'Assistant',
      _ => role,
    };

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.entries,
    required this.collapseToolParts,
    required this.isUser,
    this.onRevertPart,
  });

  final List<({MessagePart part, String? messageId})> entries;
  final bool collapseToolParts;
  final bool isUser;
  final AgentMessageRevertCallback? onRevertPart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Activity',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          for (final entry in entries)
            Builder(
              builder: (context) {
                final body = entry.part.text ?? entry.part.content ?? '';
                final messageId = entry.messageId;
                final canRevert = !isUser &&
                    onRevertPart != null &&
                    messageId != null &&
                    looksLikeUnifiedDiff(body);
                return AgentMessagePartTile(
                  part: entry.part,
                  forceCollapsed: collapseToolParts,
                  compact: true,
                  canRevert: canRevert,
                  onRevert: canRevert
                      ? () => onRevertPart!(messageId, entry.part.id)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Backwards-compatible single-message wrapper.
class AgentMessageBubble extends StatelessWidget {
  const AgentMessageBubble({
    required this.message,
    this.collapseToolParts = true,
    this.onRevertPart,
    super.key,
  });

  final MessageWithParts message;
  final bool collapseToolParts;
  final AgentMessageRevertCallback? onRevertPart;

  @override
  Widget build(BuildContext context) {
    return AgentMessageGroupBubble(
      group: AgentMessageGroup(
        role: message.info?.role ?? 'unknown',
        messages: <MessageWithParts>[message],
      ),
      collapseToolParts: collapseToolParts,
      onRevertPart: onRevertPart,
    );
  }
}
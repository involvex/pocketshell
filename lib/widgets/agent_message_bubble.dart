import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart';

import '../utils/agent_message_grouping.dart';
import 'agent_message_part_tile.dart';

class AgentMessageGroupBubble extends StatelessWidget {
  const AgentMessageGroupBubble({
    required this.group,
    this.collapseToolParts = true,
    super.key,
  });

  final AgentMessageGroup group;
  final bool collapseToolParts;

  static bool _hasExpandableActivity(List<MessagePart> parts) {
    return parts.any((MessagePart part) {
      final body = (part.text ?? part.content ?? '').trim();
      return body.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = group.role;
    final isUser = role == 'user';
    final parts = group.parts.where(isRenderablePart).toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final textParts = parts.where(isTextPart).toList();
    final activityParts = parts.where((p) => !isTextPart(p)).toList();

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
                  if (textParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    for (final part in textParts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: AgentMessagePartTile(
                          part: part,
                          forceCollapsed: collapseToolParts,
                          compact: true,
                        ),
                      ),
                  ],
                  if (activityParts.isNotEmpty) ...[
                    if (textParts.isNotEmpty) const SizedBox(height: 4),
                    if (_hasExpandableActivity(activityParts) ||
                        activityParts.length > 3)
                      _ActivitySection(
                        parts: activityParts,
                        collapseToolParts: collapseToolParts,
                      )
                    else
                      for (final part in activityParts)
                        AgentMessagePartTile(
                          part: part,
                          forceCollapsed: collapseToolParts,
                          compact: true,
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
    required this.parts,
    required this.collapseToolParts,
  });

  final List<MessagePart> parts;
  final bool collapseToolParts;

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
          for (final part in parts)
            AgentMessagePartTile(
              part: part,
              forceCollapsed: collapseToolParts,
              compact: true,
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
    super.key,
  });

  final MessageWithParts message;
  final bool collapseToolParts;

  @override
  Widget build(BuildContext context) {
    return AgentMessageGroupBubble(
      group: AgentMessageGroup(
        role: message.info?.role ?? 'unknown',
        messages: <MessageWithParts>[message],
      ),
      collapseToolParts: collapseToolParts,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart';

String _normalizePartType(MessagePart part) {
  final raw = (part.type ?? '').toLowerCase();
  if (raw.isEmpty && part.text != null) return 'text';
  return raw;
}

String _partSummary(MessagePart part) {
  final body = part.text ?? part.content ?? '';
  final firstLine = body.split('\n').firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => '',
      );
  if (firstLine.length > 72) {
    return '${firstLine.substring(0, 72)}…';
  }
  return firstLine;
}

String _humanizeType(String type) {
  return switch (type) {
    'thinking' || 'reasoning' => 'Thinking',
    'tool_call' => 'Tool call',
    'tool_result' => 'Tool result',
    'step-start' => 'Step started',
    'step-finish' => 'Step finished',
    'tool' => 'Tool',
    _ => type.replaceAll('_', ' '),
  };
}

bool _isCollapsibleType(String type) {
  return type == 'thinking' ||
      type == 'reasoning' ||
      type == 'tool' ||
      type == 'tool_call' ||
      type == 'tool_result' ||
      type == 'step-start' ||
      type == 'step-finish' ||
      (type.isNotEmpty && type != 'text');
}

IconData _iconForType(String type) {
  if (type == 'thinking' || type == 'reasoning') {
    return Icons.psychology_outlined;
  }
  return Icons.build_outlined;
}

/// Renders a single agent message part with collapsible non-text sections.
class AgentMessagePartTile extends StatefulWidget {
  const AgentMessagePartTile({
    required this.part,
    this.forceCollapsed = true,
    this.compact = false,
    super.key,
  });

  final MessagePart part;
  final bool forceCollapsed;
  final bool compact;

  @override
  State<AgentMessagePartTile> createState() => _AgentMessagePartTileState();
}

class _AgentMessagePartTileState extends State<AgentMessagePartTile> {
  bool? _expanded;

  bool get _collapsed => !(_expanded ?? !widget.forceCollapsed);

  @override
  Widget build(BuildContext context) {
    final type = _normalizePartType(widget.part);
    final body = widget.part.text ?? widget.part.content ?? '';

    if (type == 'text' || (!_isCollapsibleType(type) && body.isEmpty)) {
      if (body.trim().isEmpty) return const SizedBox.shrink();
      return SelectableText(
        body,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
      );
    }

    final label = _humanizeType(type);
    final icon = _iconForType(type);
    final summary = _partSummary(widget.part);
    final hasBody = body.trim().isNotEmpty;

    if (!hasBody) {
      return _StaticStepRow(icon: icon, label: label, compact: widget.compact);
    }

    if (!_isCollapsibleType(type)) {
      return _CollapsiblePartShell(
        icon: icon,
        title: label,
        summary: summary,
        collapsed: _collapsed,
        compact: widget.compact,
        onToggle: () => setState(() => _expanded = _collapsed),
        child: SelectableText(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.3,
              ),
        ),
      );
    }

    return _CollapsiblePartShell(
      icon: icon,
      title: label,
      summary: summary,
      collapsed: _collapsed,
      compact: widget.compact,
      onToggle: () => setState(() => _expanded = _collapsed),
      child: SelectableText(
        body,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.3,
            ),
      ),
    );
  }
}

class _StaticStepRow extends StatelessWidget {
  const _StaticStepRow({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
      child: Row(
        children: [
          Icon(icon, size: compact ? 13 : 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsiblePartShell extends StatelessWidget {
  const _CollapsiblePartShell({
    required this.icon,
    required this.title,
    required this.summary,
    required this.collapsed,
    required this.compact,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool collapsed;
  final bool compact;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.22);

    return Padding(
      padding: EdgeInsets.only(top: compact ? 2 : 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.surface.withValues(alpha: 0.35),
        ),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 4 : 5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: compact ? 13 : 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                      size: 16,
                    ),
                  ],
                ),
                if (collapsed && summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 19, top: 2),
                    child: Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ),
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: child,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

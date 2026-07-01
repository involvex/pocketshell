import 'package:opencode_api/opencode_api.dart';

/// Consecutive API messages with the same role, shown as one chat block.
class AgentMessageGroup {
  AgentMessageGroup({required this.role, required this.messages});

  final String role;
  final List<MessageWithParts> messages;

  List<MessagePart> get parts => messages
      .expand((MessageWithParts message) => message.parts ?? <MessagePart>[])
      .toList();
}

List<AgentMessageGroup> groupAgentMessages(List<MessageWithParts> messages) {
  if (messages.isEmpty) return <AgentMessageGroup>[];

  final groups = <AgentMessageGroup>[];
  for (final message in messages) {
    final role = message.info?.role ?? 'unknown';
    if (groups.isEmpty || groups.last.role != role) {
      groups.add(AgentMessageGroup(role: role, messages: <MessageWithParts>[message]));
    } else {
      groups.last.messages.add(message);
    }
  }
  return groups;
}

bool isTextPart(MessagePart part) {
  final type = (part.type ?? '').toLowerCase();
  if (type == 'text') return true;
  if (type.isEmpty && (part.text?.isNotEmpty ?? false)) return true;
  return false;
}

bool isRenderablePart(MessagePart part) {
  final body = part.text ?? part.content ?? '';
  final type = (part.type ?? '').toLowerCase();
  if (body.trim().isNotEmpty) return true;
  if (type.isEmpty) return false;
  return type != 'text';
}

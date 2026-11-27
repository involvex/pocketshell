/// Which OpenCode SSE event types should refetch chat vs the session list.
bool shouldIgnoreAgentEvent(String type) {
  return type == 'server.heartbeat' || type == 'server.connected';
}

bool shouldReloadMessagesForEvent(String type) {
  if (shouldIgnoreAgentEvent(type)) {
    return false;
  }
  return type.startsWith('session.') ||
      type.startsWith('message.') ||
      type.contains('message');
}

bool shouldRefreshSessionsForEvent(String type) {
  if (!type.startsWith('session.')) {
    return false;
  }
  return type.contains('create') ||
      type.contains('remove') ||
      type.contains('idle');
}

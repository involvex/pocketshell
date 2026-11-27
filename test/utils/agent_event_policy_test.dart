import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/agent_event_policy.dart';

void main() {
  test('ignores heartbeats', () {
    expect(shouldIgnoreAgentEvent('server.heartbeat'), isTrue);
    expect(shouldReloadMessagesForEvent('server.heartbeat'), isFalse);
  });

  test('reloads messages for message events', () {
    expect(shouldReloadMessagesForEvent('message.updated'), isTrue);
    expect(shouldRefreshSessionsForEvent('message.updated'), isFalse);
  });

  test('refreshes sessions only for create/remove/idle', () {
    expect(shouldRefreshSessionsForEvent('session.created'), isTrue);
    expect(shouldRefreshSessionsForEvent('session.idle'), isTrue);
    expect(shouldRefreshSessionsForEvent('session.updated'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/session_entry.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/ssh_provider.dart';

void main() {
  test('new sessions start with reconnect flags cleared', () {
    final entry = SessionEntry(
      name: 'lab',
      profile: SSHProfile(
        name: 'lab',
        host: 'host',
        port: 22,
        username: 'u',
      ),
    );

    expect(entry.shouldReconnectOnResume, isFalse);
    expect(entry.suppressAutoReconnect, isFalse);
    expect(entry.reconnectAttempts, 0);
    expect(SSHProvider.kMaxForegroundReconnectAttempts, 5);
  });
}

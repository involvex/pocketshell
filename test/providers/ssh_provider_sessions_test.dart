import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/config_service.dart';

void main() {
  setUp(() async {
    // Provide an in-memory SharedPreferences for tests and init ConfigService.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConfigService.init();
  });

  test('can create and switch up to 4 sessions', () {
    final provider = SSHProvider();
    for (var i = 0; i < 4; i++) {
      final profile =
          SSHProfile(name: 'p$i', host: 'host$i', username: 'u', port: 22);
      final entry = provider.createSessionFromProfile(profile, name: 'p$i');
      expect(provider.sessions.contains(entry), true);
      expect(provider.activeSessionId, entry.id);
    }
    expect(
        () => provider.createSessionFromProfile(
            SSHProfile(name: 'p5', host: 'h', username: 'u')),
        throwsStateError);
  });

  test('remove session updates activeSession', () {
    final provider = SSHProvider();
    provider.createSessionFromProfile(
        SSHProfile(name: 'a', host: 'a', username: 'u'));
    final p2 = provider.createSessionFromProfile(
        SSHProfile(name: 'b', host: 'b', username: 'u'));
    provider.removeSession(p2.id);
    expect(provider.activeSessionId, provider.sessions.first.id);
  });
}

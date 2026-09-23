import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/config_repository.dart';

void main() {
  test('idle timeout disconnects stale sessions only', () async {
    final repo = FakeConfigRepository();
    await repo.saveSettings(<String, dynamic>{
      'sessionIdleTimeoutMinutes': 30,
    });
    final provider = SSHProvider(config: repo);

    final active = provider.createSessionFromProfile(
      SSHProfile(name: 'active', host: 'a', username: 'u'),
    );
    active.isConnected = true;
    active.touch();

    final stale = provider.createSessionFromProfile(
      SSHProfile(name: 'stale', host: 'b', username: 'u'),
    );
    stale.isConnected = true;
    stale.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 45));

    final disconnected = await provider.checkIdleTimeouts();
    expect(disconnected, 1);
    expect(active.isConnected, isTrue);
    expect(stale.isConnected, isFalse);
    expect(stale.shouldReconnectOnResume, isFalse);
    provider.dispose();
  });

  test('idle check is a no-op when disabled', () async {
    final repo = FakeConfigRepository();
    await repo.saveSettings(<String, dynamic>{
      'sessionIdleTimeoutMinutes': 0,
    });
    final provider = SSHProvider(config: repo);
    final entry = provider.createSessionFromProfile(
      SSHProfile(name: 's', host: 'h', username: 'u'),
    );
    entry.isConnected = true;
    entry.lastActivityAt = DateTime.now().subtract(const Duration(hours: 5));
    expect(await provider.checkIdleTimeouts(), 0);
    expect(entry.isConnected, isTrue);
    provider.dispose();
  });
}

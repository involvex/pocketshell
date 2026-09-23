import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/known_host.dart';
import 'package:ssh_app/services/config_repository.dart';
import 'package:ssh_app/services/host_key_verification_service.dart';

void main() {
  test('KnownHost round-trips through JSON', () {
    final host = KnownHost(
      host: 'Win-Server',
      port: 22,
      keyType: 'ssh-ed25519',
      fingerprint: 'SHA256:abc123',
      firstSeen: DateTime.utc(2026, 1, 1),
    );
    final restored = KnownHost.fromJson(host.toJson());
    expect(restored.host, 'Win-Server');
    expect(restored.port, 22);
    expect(restored.fingerprint, 'SHA256:abc123');
    expect(restored.matches('win-server', 22), isTrue);
    expect(restored.matches('win-server', 2222), isFalse);
  });

  test('evaluate returns trusted/unknown/mismatch', () async {
    final repo = FakeConfigRepository();
    final service = HostKeyVerificationService(repo);
    var stored = await service.loadHosts();
    expect(
      service.evaluate(
        stored: stored,
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:x',
      ),
      HostKeyDecision.unknown,
    );

    await service.trustHost(
      const KnownHostPrompt(
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:x',
      ),
    );
    stored = await service.loadHosts();
    expect(
      service.evaluate(
        stored: stored,
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:x',
      ),
      HostKeyDecision.trusted,
    );
    expect(
      service.evaluate(
        stored: stored,
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:changed',
      ),
      HostKeyDecision.mismatch,
    );
  });

  test('trustHost replaces fingerprint on re-trust', () async {
    final repo = FakeConfigRepository();
    final service = HostKeyVerificationService(repo);
    await service.trustHost(
      const KnownHostPrompt(
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:old',
      ),
    );
    await service.trustHost(
      const KnownHostPrompt(
        host: 'h',
        port: 22,
        keyType: 'ssh-rsa',
        fingerprint: 'SHA256:new',
      ),
    );
    final stored = await service.loadHosts();
    expect(stored.length, 1);
    expect(stored.single.fingerprint, 'SHA256:new');
  });
}

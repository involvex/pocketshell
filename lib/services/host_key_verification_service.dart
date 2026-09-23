import '../models/known_host.dart';
import '../services/config_repository.dart';

/// Pure trust evaluation + persistence for SSH host keys.
///
/// Storage is the in-app `known_hosts` list (via [ConfigRepository]).
/// OS `~/.ssh/known_hosts` is intentionally never read or imported.
class HostKeyVerificationService {
  HostKeyVerificationService(this._config);

  final ConfigRepository _config;

  Future<List<KnownHost>> loadHosts() async {
    final raw = await _config.getKnownHosts();
    return raw.map(KnownHost.fromJson).toList();
  }

  Future<void> _saveHosts(List<KnownHost> hosts) async {
    await _config.saveKnownHosts(hosts.map((h) => h.toJson()).toList());
  }

  HostKeyDecision evaluate({
    required List<KnownHost> stored,
    required String host,
    required int port,
    required String keyType,
    required String fingerprint,
  }) {
    final matches = stored.where((h) => h.matches(host, port)).toList();
    if (matches.isEmpty) return HostKeyDecision.unknown;
    final exact = matches.where((h) => h.fingerprint == fingerprint).toList();
    if (exact.isNotEmpty) return HostKeyDecision.trusted;
    return HostKeyDecision.mismatch;
  }

  /// Trusts [prompt] for host+port, replacing any prior fingerprint records
  /// for that endpoint (re-trust after warning).
  Future<void> trustHost(KnownHostPrompt prompt) async {
    final hosts = await loadHosts();
    final now = DateTime.now();
    final retained =
        hosts.where((h) => !h.matches(prompt.host, prompt.port)).toList();
    final prior =
        hosts.where((h) => h.matches(prompt.host, prompt.port)).toList();
    final firstSeen = prior.isEmpty ? now : prior.first.firstSeen;
    retained.add(
      KnownHost(
        host: prompt.host,
        port: prompt.port,
        keyType: prompt.keyType,
        fingerprint: prompt.fingerprint,
        firstSeen: firstSeen,
        lastSeen: now,
      ),
    );
    await _saveHosts(retained);
  }

  Future<void> removeHost(String host, int port) async {
    final hosts = await loadHosts();
    hosts.removeWhere((h) => h.matches(host, port));
    await _saveHosts(hosts);
  }
}

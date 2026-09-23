/// Persisted SSH host-key trust record (in-app known_hosts).
///
/// Stored via [ConfigService] under the `known_hosts` key. Deliberately
/// separate from any OS `~/.ssh/known_hosts` file (not imported by design).
class KnownHost {
  const KnownHost({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.firstSeen,
    this.lastSeen,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
  final DateTime firstSeen;
  final DateTime? lastSeen;

  String get id => '$host:$port:$keyType';

  bool matches(String otherHost, int otherPort) {
    return host.toLowerCase() == otherHost.toLowerCase() && port == otherPort;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'host': host,
      'port': port,
      'keyType': keyType,
      'fingerprint': fingerprint,
      'firstSeen': firstSeen.toIso8601String(),
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
    };
  }

  factory KnownHost.fromJson(Map<String, dynamic> json) {
    return KnownHost(
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      keyType: json['keyType'] as String? ?? 'unknown',
      fingerprint: json['fingerprint'] as String,
      firstSeen: DateTime.tryParse(json['firstSeen'] as String? ?? '') ??
          DateTime.now(),
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.tryParse(json['lastSeen'] as String),
    );
  }
}

/// Prompt data passed from [SSHProvider] to UI for first-trust decisions.
class KnownHostPrompt {
  const KnownHostPrompt({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
}

/// Result of comparing a presented host key against stored trust.
enum HostKeyDecision { trusted, unknown, mismatch }

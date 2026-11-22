import 'package:uuid/uuid.dart';

/// A local TCP forward: bind [localPort] on loopback and tunnel to
/// [remoteHost]:[remotePort] over the active SSH session.
class PortForwardRule {
  PortForwardRule({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
    String? id,
    this.label = '',
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String label;
  final int localPort;
  final String remoteHost;
  final int remotePort;
  final bool enabled;

  /// RDP preset: local 3389 → remote loopback 3389.
  static PortForwardRule get rdpPreset => PortForwardRule(
        label: 'RDP',
        localPort: 3389,
        remoteHost: '127.0.0.1',
        remotePort: 3389,
      );

  PortForwardRule copyWith({
    String? id,
    String? label,
    int? localPort,
    String? remoteHost,
    int? remotePort,
    bool? enabled,
  }) {
    return PortForwardRule(
      id: id ?? this.id,
      label: label ?? this.label,
      localPort: localPort ?? this.localPort,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'localPort': localPort,
      'remoteHost': remoteHost,
      'remotePort': remotePort,
      'enabled': enabled,
    };
  }

  factory PortForwardRule.fromJson(Map<String, dynamic> json) {
    return PortForwardRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      label: json['label'] as String? ?? '',
      localPort: (json['localPort'] as num?)?.toInt() ?? 0,
      remoteHost: json['remoteHost'] as String? ?? '127.0.0.1',
      remotePort: (json['remotePort'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Parses OpenSSH `LocalForward [bind_address:]port host:hostport`.
  ///
  /// Returns null when the directive cannot be parsed.
  static PortForwardRule? tryParseLocalForward(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    final localSpec = parts[0];
    final remoteSpec = parts.sublist(1).join(' ');

    final localPort = _parsePortEnd(localSpec);
    final remote = _parseHostPort(remoteSpec);
    if (localPort == null || remote == null) {
      return null;
    }
    return PortForwardRule(
      localPort: localPort,
      remoteHost: remote.$1,
      remotePort: remote.$2,
      label: '',
      enabled: true,
    );
  }

  static int? _parsePortEnd(String spec) {
    final colon = spec.lastIndexOf(':');
    if (colon < 0) {
      return int.tryParse(spec);
    }
    return int.tryParse(spec.substring(colon + 1));
  }

  static (String, int)? _parseHostPort(String spec) {
    final colon = spec.lastIndexOf(':');
    if (colon <= 0) {
      return null;
    }
    final host = spec.substring(0, colon).trim();
    final port = int.tryParse(spec.substring(colon + 1).trim());
    if (host.isEmpty || port == null) {
      return null;
    }
    return (host, port);
  }
}

import 'package:uuid/uuid.dart';

import 'package:ssh_app/models/port_forward_rule.dart';
import '../utils/session_manager.dart';

class SSHProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final bool isServer;
  final String? startupCommand;
  final int agentPort;
  final bool useHttps;

  /// When true with [useHttps], agent TLS accepts self-signed certificates.
  /// Off by default — must be opted in per profile (LAN OpenCode).
  final bool allowSelfSignedCerts;
  final String agentUsername;
  final String? agentPassword;
  final SessionManager sessionManager;

  /// When true, Agents HTTP goes through an SSH local forward to
  /// `127.0.0.1:agentPort` on the remote host (for OpenCode bound to loopback).
  final bool tunnelAgent;

  /// Pinned to the top of the profile list when true.
  final bool isFavorite;

  /// Optional bastion profile id used for jump-host (ProxyJump) connects.
  final String? jumpProfileId;

  /// Optional NIC MAC for Wake-on-LAN (`AA:BB:CC:DD:EE:FF`).
  final String? macAddress;

  /// Named local port-forward rules started with the SSH session.
  final List<PortForwardRule> localForwards;

  SSHProfile({
    required this.name,
    required this.host,
    required this.username,
    String? id,
    this.port = 22,
    this.password,
    this.privateKey,
    this.isServer = false,
    this.startupCommand,
    this.agentPort = 5000,
    this.useHttps = false,
    this.allowSelfSignedCerts = false,
    this.agentUsername = 'opencode',
    this.agentPassword,
    this.sessionManager = SessionManager.none,
    this.tunnelAgent = false,
    this.isFavorite = false,
    this.jumpProfileId,
    this.macAddress,
    List<PortForwardRule>? localForwards,
  })  : id = id ?? const Uuid().v4(),
        localForwards = List<PortForwardRule>.unmodifiable(
          localForwards ?? const <PortForwardRule>[],
        );

  String get agentBaseUrl =>
      '${useHttps ? 'https' : 'http'}://$host:$agentPort';

  /// Loopback hosts keep HTTP Basic on-device (or via SSH tunnel).
  bool get isLoopbackAgentHost {
    final h = host.trim().toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  /// Agent HTTP Basic would leave this device without TLS or an SSH tunnel.
  bool get agentAuthUsesCleartextNetwork =>
      !useHttps && !tunnelAgent && !isLoopbackAgentHost;

  bool get agentAuthFallsBackToSshPassword {
    final agent = agentPassword;
    if (agent != null && agent.isNotEmpty) {
      return false;
    }
    final ssh = password;
    return ssh != null && ssh.isNotEmpty;
  }

  /// HTTP Basic username for OpenCode serve (never empty).
  String get effectiveAgentUsername =>
      agentUsername.isNotEmpty ? agentUsername : 'opencode';

  /// OpenCode serve password, falling back to SSH password when unset.
  String get effectiveAgentPassword {
    final agent = agentPassword;
    if (agent != null && agent.isNotEmpty) {
      return agent;
    }
    return password ?? '';
  }

  SSHProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    bool? isServer,
    String? startupCommand,
    int? agentPort,
    bool? useHttps,
    bool? allowSelfSignedCerts,
    String? agentUsername,
    String? agentPassword,
    SessionManager? sessionManager,
    bool? tunnelAgent,
    bool? isFavorite,
    String? jumpProfileId,
    bool clearJumpProfileId = false,
    String? macAddress,
    bool clearMacAddress = false,
    List<PortForwardRule>? localForwards,
  }) {
    return SSHProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      isServer: isServer ?? this.isServer,
      startupCommand: startupCommand ?? this.startupCommand,
      agentPort: agentPort ?? this.agentPort,
      useHttps: useHttps ?? this.useHttps,
      allowSelfSignedCerts: allowSelfSignedCerts ?? this.allowSelfSignedCerts,
      agentUsername: agentUsername ?? this.agentUsername,
      agentPassword: agentPassword ?? this.agentPassword,
      sessionManager: sessionManager ?? this.sessionManager,
      tunnelAgent: tunnelAgent ?? this.tunnelAgent,
      isFavorite: isFavorite ?? this.isFavorite,
      jumpProfileId:
          clearJumpProfileId ? null : (jumpProfileId ?? this.jumpProfileId),
      macAddress: clearMacAddress ? null : (macAddress ?? this.macAddress),
      localForwards: localForwards ?? this.localForwards,
    );
  }

  /// Serializes profile metadata. Passwords are stored via SecureStorageService.
  Map<String, dynamic> toJson({bool includePassword = false}) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      if (includePassword) 'password': password,
      'privateKey': _privateKeyLooksLikePem ? null : privateKey,
      'isServer': isServer,
      'startupCommand': startupCommand,
      'agentPort': agentPort,
      'useHttps': useHttps,
      'allowSelfSignedCerts': allowSelfSignedCerts,
      'agentUsername': agentUsername,
      if (includePassword) 'agentPassword': agentPassword,
      'sessionManager': sessionManager.name,
      'tunnelAgent': tunnelAgent,
      'isFavorite': isFavorite,
      if (jumpProfileId != null) 'jumpProfileId': jumpProfileId,
      if (macAddress != null) 'macAddress': macAddress,
      'localForwards':
          localForwards.map((PortForwardRule r) => r.toJson()).toList(),
    };
  }

  factory SSHProfile.fromJson(Map<String, dynamic> json) {
    final forwardsRaw = json['localForwards'];
    final forwards = <PortForwardRule>[];
    if (forwardsRaw is List) {
      for (final entry in forwardsRaw) {
        if (entry is Map) {
          forwards.add(
            PortForwardRule.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return SSHProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      isServer: json['isServer'] as bool? ?? false,
      startupCommand: json['startupCommand'] as String?,
      agentPort: json['agentPort'] as int? ?? 5000,
      useHttps: json['useHttps'] as bool? ?? false,
      allowSelfSignedCerts: json['allowSelfSignedCerts'] as bool? ?? false,
      agentUsername: json['agentUsername'] as String? ?? 'opencode',
      agentPassword: json['agentPassword'] as String?,
      sessionManager: SessionManagerX.fromStorage(
        json['sessionManager'] as String?,
      ),
      tunnelAgent: json['tunnelAgent'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      jumpProfileId: json['jumpProfileId'] as String?,
      macAddress: json['macAddress'] as String?,
      localForwards: forwards,
    );
  }

  bool get _privateKeyLooksLikePem {
    final value = privateKey;
    if (value == null) {
      return false;
    }
    return value.trimLeft().startsWith('-----BEGIN');
  }
}

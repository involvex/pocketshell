import 'package:uuid/uuid.dart';

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
  final SessionManager sessionManager;

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
    this.sessionManager = SessionManager.none,
  }) : id = id ?? const Uuid().v4();

  String get agentBaseUrl =>
      '${useHttps ? 'https' : 'http'}://$host:$agentPort';

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
    SessionManager? sessionManager,
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
      sessionManager: sessionManager ?? this.sessionManager,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'isServer': isServer,
      'startupCommand': startupCommand,
      'agentPort': agentPort,
      'useHttps': useHttps,
      'sessionManager': sessionManager.name,
    };
  }

  factory SSHProfile.fromJson(Map<String, dynamic> json) {
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
      sessionManager: SessionManagerX.fromStorage(
        json['sessionManager'] as String?,
      ),
    );
  }
}

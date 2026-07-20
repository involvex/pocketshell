import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/sftp_helper.dart';

/// Parsed OpenCode settings discovered on a remote Windows host.
class RemoteOpenCodeConfig {
  RemoteOpenCodeConfig({
    required this.sourcePath,
    required this.raw,
    this.agentPort,
    this.password,
    this.directory,
  });

  final String sourcePath;
  final Map<String, dynamic> raw;
  final int? agentPort;
  final String? password;
  final String? directory;
}

/// Reads OpenCode config files from a Windows host over SSH/SFTP.
class OpenCodeRemoteConfigService {
  const OpenCodeRemoteConfigService();

  static const List<String> _configFileNames = <String>[
    'config.json',
    'opencode.json',
    'settings.json',
  ];

  Future<RemoteOpenCodeConfig?> importFromSshClient({
    required SSHClient client,
    required SSHProfile profile,
  }) async {
    final helper = SftpHelper(client);
    try {
      final username = profile.username;

      final probeDirs = <String>[
        'C:/Users/$username/.config/opencode',
        'C:/Users/$username/AppData/Roaming/opencode',
      ];

      for (final dir in probeDirs) {
        final config = await _readFirstConfigInDir(helper, dir);
        if (config != null) {
          return _parseConfig(config.path, config.contents, profile);
        }
      }

      return null;
    } finally {
      await helper.close();
    }
  }

  Future<({String path, String contents})?> _readFirstConfigInDir(
    SftpHelper helper,
    String dir,
  ) async {
    try {
      final entries = await helper.listDir(dir);
      for (final name in _configFileNames) {
        final match = entries.any((entry) => entry.name == name);
        if (match) {
          final path = '$dir/$name';
          final text = await helper.readRemoteText(path);
          if (text != null && text.trim().isNotEmpty) {
            return (path: path, contents: text);
          }
        }
      }

      for (final entry in entries) {
        final fileName = entry.name;
        if (entry.isDirectory) continue;
        if (!fileName.endsWith('.json') && !fileName.endsWith('.toml')) {
          continue;
        }
        final path = '$dir/$fileName';
        final text = await helper.readRemoteText(path);
        if (text != null && text.trim().isNotEmpty) {
          return (path: path, contents: text);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  RemoteOpenCodeConfig? _parseConfig(
    String path,
    String contents,
    SSHProfile profile,
  ) {
    Map<String, dynamic> raw;
    try {
      if (path.endsWith('.json')) {
        raw = Map<String, dynamic>.from(
          json.decode(contents) as Map<dynamic, dynamic>,
        );
      } else {
        raw = <String, dynamic>{'rawToml': contents};
      }
    } catch (_) {
      return null;
    }

    final server = raw['server'];
    final serverMap =
        server is Map ? Map<String, dynamic>.from(server) : <String, dynamic>{};

    int? agentPort;
    final portValue = serverMap['port'] ?? raw['port'] ?? raw['agentPort'];
    if (portValue is int) {
      agentPort = portValue;
    } else if (portValue is String) {
      agentPort = int.tryParse(portValue);
    }

    final password = serverMap['password'] as String? ??
        raw['password'] as String? ??
        profile.password;

    final directory = raw['directory'] as String? ??
        raw['project'] as String? ??
        raw['cwd'] as String?;

    return RemoteOpenCodeConfig(
      sourcePath: path,
      raw: raw,
      agentPort: agentPort,
      password: password,
      directory: directory,
    );
  }
}

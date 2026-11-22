import 'dart:convert';
import 'dart:typed_data';

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

  /// Preferred Windows OpenCode config directories for [profile.username].
  static List<String> probeDirsFor(SSHProfile profile) {
    final username = profile.username;
    return <String>[
      'C:/Users/$username/.config/opencode',
      'C:/Users/$username/AppData/Roaming/opencode',
    ];
  }

  Future<RemoteOpenCodeConfig?> importFromSshClient({
    required SSHClient client,
    required SSHProfile profile,
  }) async {
    final helper = SftpHelper(client);
    try {
      for (final dir in probeDirsFor(profile)) {
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

  /// Writes [body] as JSON to an existing remote config file, or creates
  /// `opencode.json` under the first probe directory that exists (or can be
  /// created as `C:/Users/<user>/.config/opencode`).
  Future<String> writeConfigViaSshClient({
    required SSHClient client,
    required SSHProfile profile,
    required Map<String, dynamic> body,
    bool backup = true,
  }) async {
    final helper = SftpHelper(client);
    try {
      String? targetPath;
      for (final dir in probeDirsFor(profile)) {
        final existing = await _readFirstConfigInDir(helper, dir);
        if (existing != null) {
          targetPath = existing.path;
          break;
        }
      }

      targetPath ??= await _ensureDefaultConfigPath(helper, profile);

      const encoder = JsonEncoder.withIndent('  ');
      final bytes = Uint8List.fromList(
        utf8.encode('${encoder.convert(body)}\n'),
      );
      await helper.writeRemoteBytes(targetPath, bytes, backup: backup);
      return targetPath;
    } finally {
      await helper.close();
    }
  }

  Future<String> _ensureDefaultConfigPath(
    SftpHelper helper,
    SSHProfile profile,
  ) async {
    final preferredDir = probeDirsFor(profile).first;
    try {
      await helper.mkdir(preferredDir);
    } catch (_) {
      // Parent may already exist, or mkdir of nested path may need parents.
      try {
        final userHome = 'C:/Users/${profile.username}';
        final configDir = '$userHome/.config';
        if (!await helper.exists(configDir)) {
          await helper.mkdir(configDir);
        }
        if (!await helper.exists(preferredDir)) {
          await helper.mkdir(preferredDir);
        }
      } catch (e) {
        throw StateError(
          'Could not create OpenCode config directory $preferredDir: $e',
        );
      }
    }
    return '$preferredDir/opencode.json';
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

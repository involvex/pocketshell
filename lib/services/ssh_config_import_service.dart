import 'package:dartssh2/dartssh2.dart';

import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/ssh_config_parser.dart';

/// Outcome of importing OpenSSH config hosts into app profiles.
class SshConfigImportResult {
  const SshConfigImportResult({
    required this.sourcePath,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.identityHints,
    required this.skippedDirectives,
  });

  final String sourcePath;
  final int created;
  final int updated;
  final int skipped;
  final List<String> identityHints;
  final List<String> skippedDirectives;
}

/// Reads remote OpenSSH config over SFTP and maps hosts to [SSHProfile]s.
class SshConfigImportService {
  const SshConfigImportService();

  /// Loads config from Windows then POSIX paths on [client].
  Future<({String path, String contents})?> readRemoteConfig({
    required SSHClient client,
    required String username,
  }) async {
    final helper = SftpHelper(client);
    try {
      final candidates = <String>[
        'C:/Users/$username/.ssh/config',
        '/home/$username/.ssh/config',
        '/Users/$username/.ssh/config',
      ];
      for (final path in candidates) {
        try {
          final text = await helper.readRemoteText(path);
          if (text != null && text.trim().isNotEmpty) {
            return (path: path, contents: text);
          }
        } catch (_) {
          // Try next candidate.
        }
      }
      return null;
    } finally {
      await helper.close();
    }
  }

  /// Parses [contents] and merges into [existing] without touching passwords.
  ///
  /// Match key is host + port + user (case-insensitive host/user).
  /// Returns updated profile list and a summary.
  ({List<SSHProfile> profiles, SshConfigImportResult result}) mergeIntoProfiles({
    required List<SSHProfile> existing,
    required String sourcePath,
    required String contents,
    required String fallbackUsername,
  }) {
    final parsed = parseSshConfig(contents);
    final profiles = List<SSHProfile>.from(existing);
    var created = 0;
    var updated = 0;
    var skipped = 0;
    final identityHints = <String>[];
    final skippedDirectives = <String>{
      ...parsed.skippedDirectives,
    };

    for (final host in parsed.hosts) {
      skippedDirectives.addAll(host.skippedDirectives);
      final user =
          host.user.isNotEmpty ? host.user : fallbackUsername;
      if (host.hostName.isEmpty) {
        skipped++;
        continue;
      }

      final identity = host.identityFile;
      if (identity != null && identity.isNotEmpty) {
        identityHints.add('${host.alias}: $identity');
      }

      final matchIndex = profiles.indexWhere(
        (p) =>
            p.host.toLowerCase() == host.hostName.toLowerCase() &&
            p.port == host.port &&
            p.username.toLowerCase() == user.toLowerCase(),
      );

      if (matchIndex >= 0) {
        final current = profiles[matchIndex];
        profiles[matchIndex] = current.copyWith(
          name: host.alias.isNotEmpty ? host.alias : current.name,
        );
        updated++;
      } else {
        profiles.add(
          SSHProfile(
            name: host.alias,
            host: host.hostName,
            port: host.port,
            username: user,
          ),
        );
        created++;
      }
    }

    final sortedSkipped = skippedDirectives.toList()..sort();
    return (
      profiles: profiles,
      result: SshConfigImportResult(
        sourcePath: sourcePath,
        created: created,
        updated: updated,
        skipped: skipped,
        identityHints: identityHints,
        skippedDirectives: sortedSkipped,
      ),
    );
  }
}

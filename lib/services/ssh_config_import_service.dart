import 'package:dartssh2/dartssh2.dart';

import 'package:ssh_app/models/port_forward_rule.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/jump_host_utils.dart';
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
    this.unresolvedProxyJumps = const <String>[],
  });

  final String sourcePath;
  final int created;
  final int updated;
  final int skipped;
  final List<String> identityHints;
  final List<String> skippedDirectives;

  /// ProxyJump tokens that could not be mapped to an existing profile.
  final List<String> unresolvedProxyJumps;
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
  ///
  /// ProxyJump is applied when the jump alias/host already exists as a profile
  /// (including hosts created earlier in the same import). Unresolved jumps are
  /// listed in [SshConfigImportResult.unresolvedProxyJumps].
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
    final unresolvedProxyJumps = <String>{};

    // First pass: create/update host/port/user fields and local forwards.
    final pendingJumps = <String, String?>{};

    for (final host in parsed.hosts) {
      skippedDirectives.addAll(host.skippedDirectives);
      final user = host.user.isNotEmpty ? host.user : fallbackUsername;
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

      final forwards = host.localForwards.isEmpty
          ? null
          : List<PortForwardRule>.from(host.localForwards);

      if (matchIndex >= 0) {
        final current = profiles[matchIndex];
        profiles[matchIndex] = current.copyWith(
          name: host.alias.isNotEmpty ? host.alias : current.name,
          localForwards: forwards ?? current.localForwards,
        );
        pendingJumps[profiles[matchIndex].id] = host.proxyJump;
        updated++;
      } else {
        final createdProfile = SSHProfile(
          name: host.alias,
          host: host.hostName,
          port: host.port,
          username: user,
          localForwards: forwards,
        );
        profiles.add(createdProfile);
        pendingJumps[createdProfile.id] = host.proxyJump;
        created++;
      }
    }

    // Second pass: resolve ProxyJump against the merged profile list.
    for (final entry in pendingJumps.entries) {
      final token = entry.value;
      if (token == null || token.isEmpty) {
        continue;
      }
      final jumpId = resolveProxyJumpProfileId(
        profiles: profiles,
        proxyJump: token,
      );
      final index = profiles.indexWhere((p) => p.id == entry.key);
      if (index < 0) {
        continue;
      }
      if (jumpId == null) {
        unresolvedProxyJumps.add(token);
        skippedDirectives.add('ProxyJump');
        continue;
      }
      if (createsJumpCycle(profiles, entry.key, jumpId)) {
        unresolvedProxyJumps.add(token);
        continue;
      }
      profiles[index] = profiles[index].copyWith(jumpProfileId: jumpId);
    }

    final sortedSkipped = skippedDirectives.toList()..sort();
    final sortedUnresolved = unresolvedProxyJumps.toList()..sort();
    return (
      profiles: profiles,
      result: SshConfigImportResult(
        sourcePath: sourcePath,
        created: created,
        updated: updated,
        skipped: skipped,
        identityHints: identityHints,
        skippedDirectives: sortedSkipped,
        unresolvedProxyJumps: sortedUnresolved,
      ),
    );
  }
}

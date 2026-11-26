import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'package:ssh_app/models/port_forward_rule.dart';
import 'package:ssh_app/models/ssh_key.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/identity_file_path.dart';
import 'package:ssh_app/utils/jump_host_utils.dart';
import 'package:ssh_app/utils/pem_key_import.dart';
import 'package:ssh_app/utils/ssh_config_parser.dart';

/// Max remote IdentityFile size accepted during config import (64 KiB).
const int kIdentityFileMaxBytes = 64 * 1024;

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
    this.identityPulled = const <String>[],
  });

  final String sourcePath;
  final int created;
  final int updated;
  final int skipped;

  /// IdentityFile paths that were not attached (already had a key, missing,
  /// encrypted, or unreadable). Never includes key material.
  final List<String> identityHints;

  final List<String> skippedDirectives;

  /// ProxyJump tokens that could not be mapped to an existing profile.
  final List<String> unresolvedProxyJumps;

  /// Successfully pulled IdentityFiles (`alias → keyName`).
  final List<String> identityPulled;

  SshConfigImportResult copyWith({
    List<String>? identityHints,
    List<String>? identityPulled,
  }) {
    return SshConfigImportResult(
      sourcePath: sourcePath,
      created: created,
      updated: updated,
      skipped: skipped,
      identityHints: identityHints ?? this.identityHints,
      skippedDirectives: skippedDirectives,
      unresolvedProxyJumps: unresolvedProxyJumps,
      identityPulled: identityPulled ?? this.identityPulled,
    );
  }
}

/// Result of [SshConfigImportService.mergeIntoProfiles].
class SshConfigMergeOutcome {
  const SshConfigMergeOutcome({
    required this.profiles,
    required this.result,
    required this.pendingIdentityFiles,
  });

  final List<SSHProfile> profiles;
  final SshConfigImportResult result;

  /// Profile id → raw `IdentityFile` value from the config Host block.
  final Map<String, String> pendingIdentityFiles;
}

/// Result of [SshConfigImportService.pullIdentityFiles].
class IdentityFilePullOutcome {
  const IdentityFilePullOutcome({
    required this.profiles,
    required this.keys,
    required this.result,
  });

  final List<SSHProfile> profiles;
  final List<SSHKey> keys;
  final SshConfigImportResult result;
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
  ///
  /// [SshConfigMergeOutcome.pendingIdentityFiles] maps profile ids to raw
  /// IdentityFile paths for a subsequent [pullIdentityFiles] pass.
  SshConfigMergeOutcome mergeIntoProfiles({
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
    final pendingIdentityFiles = <String, String>{};
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

      final matchIndex = profiles.indexWhere(
        (p) =>
            p.host.toLowerCase() == host.hostName.toLowerCase() &&
            p.port == host.port &&
            p.username.toLowerCase() == user.toLowerCase(),
      );

      final forwards = host.localForwards.isEmpty
          ? null
          : List<PortForwardRule>.from(host.localForwards);

      late final String profileId;
      if (matchIndex >= 0) {
        final current = profiles[matchIndex];
        profiles[matchIndex] = current.copyWith(
          name: host.alias.isNotEmpty ? host.alias : current.name,
          localForwards: forwards ?? current.localForwards,
        );
        profileId = profiles[matchIndex].id;
        pendingJumps[profileId] = host.proxyJump;
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
        profileId = createdProfile.id;
        pendingJumps[profileId] = host.proxyJump;
        created++;
      }

      final identity = host.identityFile;
      if (identity != null && identity.isNotEmpty) {
        pendingIdentityFiles[profileId] = identity;
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
    return SshConfigMergeOutcome(
      profiles: profiles,
      pendingIdentityFiles: pendingIdentityFiles,
      result: SshConfigImportResult(
        sourcePath: sourcePath,
        created: created,
        updated: updated,
        skipped: skipped,
        identityHints: const <String>[],
        skippedDirectives: sortedSkipped,
        unresolvedProxyJumps: sortedUnresolved,
      ),
    );
  }

  /// Downloads pending IdentityFiles over [helper] and attaches new [SSHKey]s.
  ///
  /// Profiles that already have [SSHProfile.privateKey] keep it and get a hint.
  /// Failed reads / encrypted PEMs become hints; the rest of the import is kept.
  /// Key material is never added to hints or the result summary.
  Future<IdentityFilePullOutcome> pullIdentityFiles({
    required List<SSHProfile> profiles,
    required Map<String, String> pendingIdentityFiles,
    required String configPath,
    required String username,
    required SftpFileSystem helper,
    SshConfigImportResult? baseResult,
  }) async {
    final updatedProfiles = List<SSHProfile>.from(profiles);
    final importedKeys = <SSHKey>[];
    final pulled = <String>[];
    final hints = <String>[];
    final keysByResolvedPath = <String, SSHKey>{};

    for (final entry in pendingIdentityFiles.entries) {
      final profileIndex =
          updatedProfiles.indexWhere((p) => p.id == entry.key);
      if (profileIndex < 0) {
        continue;
      }
      final profile = updatedProfiles[profileIndex];
      final alias = profile.name;
      final rawPath = entry.value;

      final existingRef = profile.privateKey?.trim();
      if (existingRef != null && existingRef.isNotEmpty) {
        hints.add('$alias: already has a key (skipped $rawPath)');
        continue;
      }

      final candidates = identityFileCandidates(
        identityFile: rawPath,
        configPath: configPath,
        username: username,
      );
      if (candidates.isEmpty) {
        hints.add('$alias: empty IdentityFile');
        continue;
      }

      SSHKey? key;
      String? resolvedPath;
      String? lastError;

      for (final candidate in candidates) {
        final cached = keysByResolvedPath[candidate];
        if (cached != null) {
          key = cached;
          resolvedPath = candidate;
          break;
        }

        late final String pemText;
        try {
          final bytes = await helper.readRemoteBytes(
            candidate,
            maxBytes: kIdentityFileMaxBytes,
          );
          pemText = utf8.decode(bytes, allowMalformed: false);
        } catch (_) {
          lastError = 'not found or unreadable at $candidate';
          continue;
        }

        final baseName = identityFileBaseName(candidate);
        final imported = tryImportUnencryptedPemKey(
          pemText,
          name: '$alias ($baseName)',
        );
        if (!imported.isOk) {
          lastError =
              '${pemKeyImportFailureMessage(imported.failure!)} ($candidate)';
          continue;
        }
        key = imported.key;
        resolvedPath = candidate;
        keysByResolvedPath[candidate] = key!;
        break;
      }

      if (key == null || resolvedPath == null) {
        hints.add('$alias: ${lastError ?? 'IdentityFile pull failed'}');
        continue;
      }

      if (!importedKeys.any((k) => k.id == key!.id)) {
        importedKeys.add(key);
      }
      updatedProfiles[profileIndex] = profile.copyWith(privateKey: key.id);
      pulled.add('$alias → ${key.name}');
    }

    final base = baseResult ??
        SshConfigImportResult(
          sourcePath: configPath,
          created: 0,
          updated: 0,
          skipped: 0,
          identityHints: const <String>[],
          skippedDirectives: const <String>[],
        );

    return IdentityFilePullOutcome(
      profiles: updatedProfiles,
      keys: importedKeys,
      result: base.copyWith(
        identityHints: List<String>.unmodifiable(hints),
        identityPulled: List<String>.unmodifiable(pulled),
      ),
    );
  }
}

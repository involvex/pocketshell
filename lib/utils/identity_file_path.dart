import 'package:ssh_app/utils/remote_path_utils.dart';

/// Resolves OpenSSH `IdentityFile` values into absolute remote paths to try.
///
/// Expands `~` against the home directory implied by [configPath] (the file
/// that was actually read), falling back to [username]-based homes. Relative
/// paths are joined to the config file's directory. Never logs key contents.
List<String> identityFileCandidates({
  required String identityFile,
  required String configPath,
  required String username,
}) {
  final raw = identityFile.trim().replaceAll(r'\', '/');
  if (raw.isEmpty) {
    return const <String>[];
  }

  final normalizedConfig = RemotePath.normalize(configPath);
  final configDir = RemotePath.parent(normalizedConfig);
  final isWindowsConfig = RegExp(r'^[A-Za-z]:/').hasMatch(normalizedConfig);
  final homeFromConfig = homeDirectoryFromSshConfigPath(normalizedConfig);

  if (RegExp(r'^[A-Za-z]:/').hasMatch(raw) || raw.startsWith('/')) {
    return <String>[RemotePath.normalize(raw)];
  }

  if (raw == '~' || raw.startsWith('~/')) {
    final rest = raw == '~' ? '' : raw.substring(2);
    final homes = <String>[];
    if (homeFromConfig != null) {
      homes.add(homeFromConfig);
    }
    if (isWindowsConfig) {
      final winHome = RemotePath.normalize('C:/Users/$username');
      if (!homes.contains(winHome)) {
        homes.add(winHome);
      }
    } else {
      for (final candidate in <String>[
        '/home/$username',
        '/Users/$username',
      ]) {
        final normalized = RemotePath.normalize(candidate);
        if (!homes.contains(normalized)) {
          homes.add(normalized);
        }
      }
    }

    return homes
        .map(
          (home) => rest.isEmpty
              ? home
              : RemotePath.join(home, rest),
        )
        .toList(growable: false);
  }

  return <String>[RemotePath.join(configDir, raw)];
}

/// Derives the user home from a path like `C:/Users/x/.ssh/config`.
String? homeDirectoryFromSshConfigPath(String configPath) {
  final normalized = RemotePath.normalize(configPath);
  final sshDir = RemotePath.parent(normalized);
  final segments = sshDir.split('/');
  if (segments.isEmpty || segments.last != '.ssh') {
    return null;
  }
  return RemotePath.parent(sshDir);
}

/// Last path segment of an IdentityFile path (for key naming).
String identityFileBaseName(String path) {
  final normalized = RemotePath.normalize(path);
  final index = normalized.lastIndexOf('/');
  if (index < 0 || index >= normalized.length - 1) {
    return normalized;
  }
  return normalized.substring(index + 1);
}

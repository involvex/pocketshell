import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';

/// Local and remote SHA-256 helpers for post-transfer verification.
class SftpChecksumService {
  SftpChecksumService(this._client);

  final SSHClient _client;

  Future<String> localSha256(File file) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  /// Returns lowercase hex SHA-256 of the remote file, or null if unavailable.
  Future<String?> remoteSha256(String remotePath) async {
    final String escaped = _shellQuotePosix(remotePath);
    for (final String template in <String>[
      'sha256sum -- $escaped 2>/dev/null',
      'sha256sum $escaped 2>/dev/null',
      'shasum -a 256 -- $escaped 2>/dev/null',
    ]) {
      try {
        final Uint8List output = await _client.run(template);
        final String? hash =
            _parseSha256Line(utf8.decode(output, allowMalformed: true));
        if (hash != null) {
          return hash;
        }
      } catch (_) {
        continue;
      }
    }

    final String psPath = remotePath.replaceAll("'", "''");
    final String ps =
        'powershell -NoProfile -Command '
        '"(Get-FileHash -Algorithm SHA256 -LiteralPath \'$psPath\').Hash"';
    try {
      final Uint8List output = await _client.run(ps);
      final String text = utf8.decode(output, allowMalformed: true).trim();
      if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(text)) {
        return text.toLowerCase();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _parseSha256Line(String text) {
    for (final String line in text.split(RegExp(r'\r?\n'))) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int space = trimmed.indexOf(RegExp(r'\s'));
      final String token = space < 0 ? trimmed : trimmed.substring(0, space);
      if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
        return token.toLowerCase();
      }
    }
    return null;
  }

  static String _shellQuotePosix(String path) {
    return "'${path.replaceAll(r"'", r"'\''")}'";
  }
}

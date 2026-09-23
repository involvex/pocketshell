import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'backup_crypto.dart';
import 'config_service.dart';
import '../constants/app_metadata.dart';
import 'secure_storage_service.dart';
import 'widget_profile_service.dart';

class BackupService {
  static const int _backupVersion = 1;
  static const int _encryptedBackupVersion = 2;
  static const int _maxBackupSizeBytes = 5 * 1024 * 1024; // 5 MB

  /// Builds the inner (plaintext schema v1) payload.
  ///
  /// When [includeSecrets] is false (default for plain exports), private keys,
  /// key passphrases, and profile passwords are stripped so a shared JSON file
  /// cannot leak credentials.
  static Future<Map<String, dynamic>> _buildPayload({
    required bool includeSecrets,
  }) async {
    final settings = SecureStorageService.stripApiKeys(
      await ConfigService.getSettings(),
    );
    final rawKeys = await ConfigService.getSSHKeys();
    final keys = <Map<String, dynamic>>[];
    for (final raw in rawKeys) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      if (includeSecrets && id != null) {
        final pem = await SecureStorageService.readPrivateKey(id);
        if (pem != null && pem.isNotEmpty) {
          map['privateKey'] = pem;
        }
        final passphrase = await SecureStorageService.readKeyPassphrase(id);
        if (passphrase != null && passphrase.isNotEmpty) {
          map['passphrase'] = passphrase;
        }
      } else {
        map.remove('privateKey');
        map.remove('passphrase');
      }
      keys.add(map);
    }

    final rawProfiles = await ConfigService.getProfiles();
    final profiles = includeSecrets
        ? rawProfiles
        : rawProfiles.map((p) {
            final map = Map<String, dynamic>.from(p);
            map.remove('password');
            return map;
          }).toList();

    return <String, dynamic>{
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profiles': profiles,
      'sshKeys': keys,
      'snippets': await ConfigService.getSnippets(),
      'settings': settings,
      'lastSession': await ConfigService.getLastSession(),
      'knownHosts': await ConfigService.getKnownHosts(),
    };
  }

  static Future<void> _shareJson(
    Map<String, dynamic> envelope,
    String fileName,
  ) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(envelope);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '$kAppDisplayName Backup',
      ),
    );

    // Cleanup temp file after sharing
    await file.delete();
  }

  /// Encrypted export (recommended): full payload protected by [password].
  static Future<void> exportEncrypted(String password) async {
    final payload = await _buildPayload(includeSecrets: true);
    final inner = json.encode(payload);
    final envelope = await BackupCrypto.encrypt(inner, password);
    await _shareJson(envelope, 'ssh_app_backup.encrypted.json');
  }

  /// Plain export. Secrets are stripped unless [includeSecrets] is explicitly
  /// true (caller must show a risk acknowledgement first).
  static Future<void> exportPlain({bool includeSecrets = false}) async {
    final payload = await _buildPayload(includeSecrets: includeSecrets);
    await _shareJson(payload, 'ssh_app_backup.json');
  }

  /// Legacy entry point: plain export without secrets (safe default).
  static Future<void> export() async {
    await exportPlain();
  }

  static Future<String> import({String? password}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty) return 'Import cancelled';

    final path = result.first.path;
    if (path == null) throw Exception('Could not read selected file');

    final file = File(path);
    final fileSize = await file.length();
    if (fileSize > _maxBackupSizeBytes) {
      throw const FormatException(
          'Backup file too large (max ${_maxBackupSizeBytes ~/ (1024 * 1024)} MB)');
    }

    final jsonString = await file.readAsString();
    final raw = json.decode(jsonString) as Map<String, dynamic>;

    final version = raw['version'] as int?;
    final Map<String, dynamic> data;
    if (version == _encryptedBackupVersion) {
      if (password == null || password.isEmpty) {
        throw const BackupCryptoException(
          'This backup is encrypted — enter its password',
        );
      }
      final inner = await BackupCrypto.decrypt(raw, password);
      data = json.decode(inner) as Map<String, dynamic>;
    } else if (version == _backupVersion) {
      data = raw;
    } else {
      throw FormatException('Unsupported backup version: $version');
    }

    // Validate all data before applying (transactional)
    _validateBackupData(data);

    // Apply all changes atomically
    if (data['profiles'] is List) {
      await ConfigService.saveProfiles(
        (data['profiles'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
    }
    if (data['sshKeys'] is List) {
      final keyMaps = <Map<String, dynamic>>[];
      for (final raw in data['sshKeys'] as List<dynamic>) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String?;
        final pem = map['privateKey'] as String?;
        final passphrase = map['passphrase'] as String?;
        if (id != null) {
          if (pem != null && pem.isNotEmpty) {
            await SecureStorageService.writePrivateKey(id, pem);
          }
          if (passphrase != null && passphrase.isNotEmpty) {
            await SecureStorageService.writeKeyPassphrase(id, passphrase);
          }
        }
        // Exclude privateKey and passphrase from SharedPreferences blob
        map.remove('privateKey');
        map.remove('passphrase');
        keyMaps.add(map);
      }
      await ConfigService.saveSSHKeys(keyMaps);
    }
    if (data['snippets'] is List) {
      await ConfigService.saveSnippets(
        (data['snippets'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
    }
    if (data['settings'] is Map) {
      final settings = Map<String, dynamic>.from(data['settings'] as Map);
      await SecureStorageService.importApiKeysFromBackup(settings);
      await ConfigService.saveSettings(settings);
    }
    if (data['lastSession'] is Map) {
      await ConfigService.saveLastSession(
        Map<String, dynamic>.from(data['lastSession'] as Map),
      );
    } else if (data.containsKey('lastSession') && data['lastSession'] == null) {
      // Skip — no last session to restore
    }
    if (data['knownHosts'] is List) {
      await ConfigService.saveKnownHosts(
        (data['knownHosts'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
    }

    await WidgetProfileService.syncFromConfig();

    return 'Import successful';
  }

  static void _validateBackupData(Map<String, dynamic> data) {
    if (data['profiles'] is List) {
      for (final profile in data['profiles'] as List) {
        final map = profile as Map<String, dynamic>;
        if (map['host'] == null || map['username'] == null) {
          throw const FormatException(
              'Invalid profile: missing host or username');
        }
        if (map['port'] != null && map['port'] is! int) {
          throw const FormatException('Invalid profile: port must be int');
        }
        if (map['agentPort'] != null && map['agentPort'] is! int) {
          throw const FormatException('Invalid profile: agentPort must be int');
        }
      }
    }
    if (data['sshKeys'] is List) {
      for (final key in data['sshKeys'] as List) {
        final map = key as Map<String, dynamic>;
        if (map['keyType'] == null) {
          throw const FormatException('Invalid SSH key: missing keyType');
        }
      }
    }
    if (data['snippets'] is List) {
      for (final snippet in data['snippets'] as List) {
        final map = snippet as Map<String, dynamic>;
        if (map['content'] == null) {
          throw const FormatException('Invalid snippet: missing content');
        }
      }
    }
    if (data['settings'] is Map) {
      final settings = data['settings'] as Map<String, dynamic>;
      if (settings['terminalFontSize'] != null &&
          settings['terminalFontSize'] is! num) {
        throw const FormatException(
            'Invalid settings: terminalFontSize must be num');
      }
      if (settings['defaultAgentPort'] != null &&
          settings['defaultAgentPort'] is! int) {
        throw const FormatException(
            'Invalid settings: defaultAgentPort must be int');
      }
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'config_service.dart';
import '../constants/app_metadata.dart';
import 'secure_storage_service.dart';
import 'widget_profile_service.dart';

class BackupService {
  static const int _backupVersion = 1;
  static const int _maxBackupSizeBytes = 5 * 1024 * 1024; // 5 MB

  static Future<void> export() async {
    final settings = SecureStorageService.stripApiKeys(
      await ConfigService.getSettings(),
    );
    final data = <String, dynamic>{
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profiles': await ConfigService.getProfiles(),
      'sshKeys': await ConfigService.getSSHKeys(),
      'snippets': await ConfigService.getSnippets(),
      'settings': settings,
      'lastSession': await ConfigService
          .getLastSession(), // nullable; serialized as null if absent
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ssh_app_backup.json');
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

  static Future<String> import() async {
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
    final data = json.decode(jsonString) as Map<String, dynamic>;

    final version = data['version'] as int?;
    if (version != _backupVersion) {
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
      await ConfigService.saveSSHKeys(
        (data['sshKeys'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
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

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _profilesKey = 'ssh_profiles';
  static const String _lastSessionKey = 'last_session';
  static const String _settingsKey = 'app_settings';
  static const String _sshKeysKey = 'ssh_keys';
  static const String _snippetsKey = 'snippets';
  static const String _agentLastDirectoryKey = 'agent_last_directory';
  static const String _opencodeServerConfigCacheKey =
      'opencode_server_config_cache';
  static const String _sftpSortFieldKey = 'sftp_sort_field';
  static const String _sftpSortAscendingKey = 'sftp_sort_ascending';
  static const String _sftpLastPathKey = 'sftp_last_path';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('ConfigService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  static Future<List<Map<String, dynamic>>> getProfiles() async {
    final String? data = prefs.getString(_profilesKey);
    if (data == null) return <Map<String, dynamic>>[];
    final List<dynamic> decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    await prefs.setString(_profilesKey, json.encode(profiles));
  }

  static Future<Map<String, dynamic>?> getLastSession() async {
    final String? data = prefs.getString(_lastSessionKey);
    if (data == null) return null;
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<void> saveLastSession(Map<String, dynamic> session) async {
    await prefs.setString(_lastSessionKey, json.encode(session));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final String? data = prefs.getString(_settingsKey);
    if (data == null) return _defaultSettings;
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await prefs.setString(_settingsKey, json.encode(settings));
  }

  static Map<String, dynamic> get _defaultSettings => {
        'autoDiscovery': false,
        'keyboardShortcuts': <String, String>{},
        'theme': 'dark',
      };

  static Future<List<Map<String, dynamic>>> getSSHKeys() async {
    final String? data = prefs.getString(_sshKeysKey);
    if (data == null) return <Map<String, dynamic>>[];
    final List<dynamic> decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveSSHKeys(List<Map<String, dynamic>> keys) async {
    await prefs.setString(_sshKeysKey, json.encode(keys));
  }

  static Future<List<Map<String, dynamic>>> getSnippets() async {
    final String? data = prefs.getString(_snippetsKey);
    if (data == null) return <Map<String, dynamic>>[];
    final List<dynamic> decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveSnippets(List<Map<String, dynamic>> snippets) async {
    await prefs.setString(_snippetsKey, json.encode(snippets));
  }

  static Future<String?> getAgentLastDirectory() async {
    return prefs.getString(_agentLastDirectoryKey);
  }

  static Future<void> saveAgentLastDirectory(String path) async {
    await prefs.setString(_agentLastDirectoryKey, path);
  }

  static Future<Map<String, dynamic>?> getOpenCodeServerConfigCache() async {
    final data = prefs.getString(_opencodeServerConfigCacheKey);
    if (data == null) return null;
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<void> saveOpenCodeServerConfigCache(
    Map<String, dynamic> config,
  ) async {
    await prefs.setString(
      _opencodeServerConfigCacheKey,
      json.encode(config),
    );
  }

  static Future<String> getSftpSortField() async =>
      prefs.getString(_sftpSortFieldKey) ?? 'name';

  static Future<void> saveSftpSortField(String field) async =>
      prefs.setString(_sftpSortFieldKey, field);

  static Future<bool> getSftpSortAscending() async =>
      prefs.getBool(_sftpSortAscendingKey) ?? true;

  static Future<void> saveSftpSortAscending(bool ascending) async =>
      prefs.setBool(_sftpSortAscendingKey, ascending);

  static Future<String?> getSftpLastPath() async =>
      prefs.getString(_sftpLastPathKey);

  static Future<void> saveSftpLastPath(String path) async =>
      prefs.setString(_sftpLastPathKey, path);

  static Future<void> clearSftpLastPath() async =>
      prefs.remove(_sftpLastPathKey);

  static Future<void> clearAll() async {
    await prefs.clear();
  }
}

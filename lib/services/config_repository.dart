import 'dart:convert';

import 'config_service.dart';

abstract interface class ConfigRepository {
  Future<void> init();
  Future<List<Map<String, dynamic>>> getProfiles();
  Future<void> saveProfiles(List<Map<String, dynamic>> profiles);
  Future<Map<String, dynamic>?> getLastSession();
  Future<void> saveLastSession(Map<String, dynamic> session);
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<List<Map<String, dynamic>>> getSSHKeys();
  Future<void> saveSSHKeys(List<Map<String, dynamic>> keys);
  Future<List<Map<String, dynamic>>> getSnippets();
  Future<void> saveSnippets(List<Map<String, dynamic>> snippets);
  Future<String?> getAgentLastDirectory();
  Future<void> saveAgentLastDirectory(String path);
  Future<Map<String, dynamic>?> getOpenCodeServerConfigCache();
  Future<void> saveOpenCodeServerConfigCache(Map<String, dynamic> config);
  Future<String> getSftpSortField();
  Future<void> saveSftpSortField(String field);
  Future<bool> getSftpSortAscending();
  Future<void> saveSftpSortAscending(bool ascending);
  Future<String?> getSftpLastPath();
  Future<void> saveSftpLastPath(String path);
  Future<void> clearSftpLastPath();
  Future<void> clearAll();
}

class ConfigServiceRepository implements ConfigRepository {
  @override
  Future<void> init() => ConfigService.init();

  @override
  Future<List<Map<String, dynamic>>> getProfiles() =>
      ConfigService.getProfiles();

  @override
  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) =>
      ConfigService.saveProfiles(profiles);

  @override
  Future<Map<String, dynamic>?> getLastSession() =>
      ConfigService.getLastSession();

  @override
  Future<void> saveLastSession(Map<String, dynamic> session) =>
      ConfigService.saveLastSession(session);

  @override
  Future<Map<String, dynamic>> getSettings() => ConfigService.getSettings();

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) =>
      ConfigService.saveSettings(settings);

  @override
  Future<List<Map<String, dynamic>>> getSSHKeys() => ConfigService.getSSHKeys();

  @override
  Future<void> saveSSHKeys(List<Map<String, dynamic>> keys) =>
      ConfigService.saveSSHKeys(keys);

  @override
  Future<List<Map<String, dynamic>>> getSnippets() =>
      ConfigService.getSnippets();

  @override
  Future<void> saveSnippets(List<Map<String, dynamic>> snippets) =>
      ConfigService.saveSnippets(snippets);

  @override
  Future<String?> getAgentLastDirectory() =>
      ConfigService.getAgentLastDirectory();

  @override
  Future<void> saveAgentLastDirectory(String path) =>
      ConfigService.saveAgentLastDirectory(path);

  @override
  Future<Map<String, dynamic>?> getOpenCodeServerConfigCache() =>
      ConfigService.getOpenCodeServerConfigCache();

  @override
  Future<void> saveOpenCodeServerConfigCache(Map<String, dynamic> config) =>
      ConfigService.saveOpenCodeServerConfigCache(config);

  @override
  Future<String> getSftpSortField() => ConfigService.getSftpSortField();

  @override
  Future<void> saveSftpSortField(String field) =>
      ConfigService.saveSftpSortField(field);

  @override
  Future<bool> getSftpSortAscending() => ConfigService.getSftpSortAscending();

  @override
  Future<void> saveSftpSortAscending(bool ascending) =>
      ConfigService.saveSftpSortAscending(ascending);

  @override
  Future<String?> getSftpLastPath() => ConfigService.getSftpLastPath();

  @override
  Future<void> saveSftpLastPath(String path) =>
      ConfigService.saveSftpLastPath(path);

  @override
  Future<void> clearSftpLastPath() => ConfigService.clearSftpLastPath();

  @override
  Future<void> clearAll() => ConfigService.clearAll();
}

/// In-memory implementation for testing.
class FakeConfigRepository implements ConfigRepository {
  final Map<String, dynamic> _store = {};

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

  static const Map<String, dynamic> _defaultSettings = {
    'autoDiscovery': false,
    'keyboardShortcuts': <String, String>{},
    'theme': 'dark',
  };

  @override
  Future<void> init() async {}

  @override
  Future<List<Map<String, dynamic>>> getProfiles() async {
    final data = _store[_profilesKey] as String?;
    if (data == null) return <Map<String, dynamic>>[];
    final decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    _store[_profilesKey] = json.encode(profiles);
  }

  @override
  Future<Map<String, dynamic>?> getLastSession() async {
    final data = _store[_lastSessionKey] as String?;
    if (data == null) return null;
    return json.decode(data) as Map<String, dynamic>;
  }

  @override
  Future<void> saveLastSession(Map<String, dynamic> session) async {
    _store[_lastSessionKey] = json.encode(session);
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final data = _store[_settingsKey] as String?;
    if (data == null) return Map<String, dynamic>.from(_defaultSettings);
    return json.decode(data) as Map<String, dynamic>;
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    _store[_settingsKey] = json.encode(settings);
  }

  @override
  Future<List<Map<String, dynamic>>> getSSHKeys() async {
    final data = _store[_sshKeysKey] as String?;
    if (data == null) return <Map<String, dynamic>>[];
    final decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> saveSSHKeys(List<Map<String, dynamic>> keys) async {
    _store[_sshKeysKey] = json.encode(keys);
  }

  @override
  Future<List<Map<String, dynamic>>> getSnippets() async {
    final data = _store[_snippetsKey] as String?;
    if (data == null) return <Map<String, dynamic>>[];
    final decoded = json.decode(data) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> saveSnippets(List<Map<String, dynamic>> snippets) async {
    _store[_snippetsKey] = json.encode(snippets);
  }

  @override
  Future<String?> getAgentLastDirectory() async {
    return _store[_agentLastDirectoryKey] as String?;
  }

  @override
  Future<void> saveAgentLastDirectory(String path) async {
    _store[_agentLastDirectoryKey] = path;
  }

  @override
  Future<Map<String, dynamic>?> getOpenCodeServerConfigCache() async {
    final data = _store[_opencodeServerConfigCacheKey] as String?;
    if (data == null) return null;
    return json.decode(data) as Map<String, dynamic>;
  }

  @override
  Future<void> saveOpenCodeServerConfigCache(
      Map<String, dynamic> config) async {
    _store[_opencodeServerConfigCacheKey] = json.encode(config);
  }

  @override
  Future<String> getSftpSortField() async =>
      _store[_sftpSortFieldKey] as String? ?? 'name';

  @override
  Future<void> saveSftpSortField(String field) async {
    _store[_sftpSortFieldKey] = field;
  }

  @override
  Future<bool> getSftpSortAscending() async =>
      _store[_sftpSortAscendingKey] as bool? ?? true;

  @override
  Future<void> saveSftpSortAscending(bool ascending) async {
    _store[_sftpSortAscendingKey] = ascending;
  }

  @override
  Future<String?> getSftpLastPath() async =>
      _store[_sftpLastPathKey] as String?;

  @override
  Future<void> saveSftpLastPath(String path) async {
    _store[_sftpLastPathKey] = path;
  }

  @override
  Future<void> clearSftpLastPath() async {
    _store.remove(_sftpLastPathKey);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

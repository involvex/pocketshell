import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _opencodeZenApiKeyKey = 'opencode_zen_api_key';
  static const String _kiloApiKeyKey = 'kilo_api_key';
  static const String _profilePasswordPrefix = 'ssh_profile_password_';
  static const String _keyPassphrasePrefix = 'ssh_key_passphrase_';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String> readOpencodeZenApiKey() async {
    return await _storage.read(key: _opencodeZenApiKeyKey) ?? '';
  }

  static Future<String> readKiloApiKey() async {
    return await _storage.read(key: _kiloApiKeyKey) ?? '';
  }

  static Future<void> writeOpencodeZenApiKey(String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: _opencodeZenApiKeyKey);
      return;
    }
    await _storage.write(key: _opencodeZenApiKeyKey, value: value);
  }

  static Future<void> writeKiloApiKey(String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: _kiloApiKeyKey);
      return;
    }
    await _storage.write(key: _kiloApiKeyKey, value: value);
  }

  static String _profilePasswordKey(String profileId) =>
      '$_profilePasswordPrefix$profileId';

  static String _keyPassphraseKey(String keyId) =>
      '$_keyPassphrasePrefix$keyId';

  static Future<String?> readProfilePassword(String profileId) async {
    return _storage.read(key: _profilePasswordKey(profileId));
  }

  static Future<void> writeProfilePassword(
    String profileId,
    String? password,
  ) async {
    final key = _profilePasswordKey(profileId);
    if (password == null || password.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: password);
  }

  static Future<void> deleteProfilePassword(String profileId) async {
    await _storage.delete(key: _profilePasswordKey(profileId));
  }

  static Future<String?> readKeyPassphrase(String keyId) async {
    return _storage.read(key: _keyPassphraseKey(keyId));
  }

  static Future<void> writeKeyPassphrase(
    String keyId,
    String? passphrase,
  ) async {
    final key = _keyPassphraseKey(keyId);
    if (passphrase == null || passphrase.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: passphrase);
  }

  static Future<void> deleteKeyPassphrase(String keyId) async {
    await _storage.delete(key: _keyPassphraseKey(keyId));
  }

  /// Migrates plaintext profile passwords into secure storage.
  ///
  /// Returns updated profile maps with `password` cleared when migrated.
  static Future<List<Map<String, dynamic>>> migrateProfilePasswords(
    List<Map<String, dynamic>> profiles,
  ) async {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final raw in profiles) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      final password = map['password'] as String?;
      if (id != null && password != null && password.isNotEmpty) {
        await writeProfilePassword(id, password);
        map['password'] = null;
        changed = true;
      }
      out.add(map);
    }
    if (changed) {
      return out;
    }
    return profiles;
  }

  /// Migrates plaintext key passphrases into secure storage.
  static Future<List<Map<String, dynamic>>> migrateKeyPassphrases(
    List<Map<String, dynamic>> keys,
  ) async {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final raw in keys) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      final passphrase = map['passphrase'] as String?;
      if (id != null && passphrase != null && passphrase.isNotEmpty) {
        await writeKeyPassphrase(id, passphrase);
        map['passphrase'] = null;
        changed = true;
      }
      out.add(map);
    }
    if (changed) {
      return out;
    }
    return keys;
  }

  /// Moves legacy plain-text keys from [settings] into secure storage.
  ///
  /// Returns `true` when keys were migrated and should be removed from settings.
  static Future<bool> migrateApiKeysFromSettings(
    Map<String, dynamic> settings,
  ) async {
    var migrated = false;

    final opencodeKey = settings['opencodeZenApiKey'] as String?;
    if (opencodeKey != null && opencodeKey.isNotEmpty) {
      await writeOpencodeZenApiKey(opencodeKey);
      settings.remove('opencodeZenApiKey');
      migrated = true;
    }

    final kiloKey = settings['kiloApiKey'] as String?;
    if (kiloKey != null && kiloKey.isNotEmpty) {
      await writeKiloApiKey(kiloKey);
      settings.remove('kiloApiKey');
      migrated = true;
    }

    return migrated;
  }

  static Future<void> importApiKeysFromBackup(
    Map<String, dynamic> settings,
  ) async {
    final opencodeKey = settings['opencodeZenApiKey'] as String?;
    if (opencodeKey != null && opencodeKey.isNotEmpty) {
      await writeOpencodeZenApiKey(opencodeKey);
    }

    final kiloKey = settings['kiloApiKey'] as String?;
    if (kiloKey != null && kiloKey.isNotEmpty) {
      await writeKiloApiKey(kiloKey);
    }

    settings.remove('opencodeZenApiKey');
    settings.remove('kiloApiKey');
  }

  static Map<String, dynamic> stripApiKeys(Map<String, dynamic> settings) {
    return Map<String, dynamic>.from(settings)
      ..remove('opencodeZenApiKey')
      ..remove('kiloApiKey');
  }
}

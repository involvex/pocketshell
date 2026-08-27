// Backwards-compatible static API delegating to [SecureStorageImpl].
// New code should depend on the [SecureStorage] interface instead.
import 'secure_storage.dart';

class SecureStorageService {
  static final SecureStorage _impl = SecureStorageImpl();

  static Future<String> readOpencodeZenApiKey() async {
    return _impl.readOpencodeZenApiKey();
  }

  static Future<String> readKiloApiKey() async {
    return _impl.readKiloApiKey();
  }

  static Future<void> writeOpencodeZenApiKey(String value) async {
    return _impl.writeOpencodeZenApiKey(value);
  }

  static Future<void> writeKiloApiKey(String value) async {
    return _impl.writeKiloApiKey(value);
  }

  static Future<String?> readProfilePassword(String profileId) async {
    return _impl.readProfilePassword(profileId);
  }

  static Future<void> writeProfilePassword(
    String profileId,
    String? password,
  ) async {
    return _impl.writeProfilePassword(profileId, password);
  }

  static Future<void> deleteProfilePassword(String profileId) async {
    return _impl.deleteProfilePassword(profileId);
  }

  static Future<String?> readKeyPassphrase(String keyId) async {
    return _impl.readKeyPassphrase(keyId);
  }

  static Future<void> writeKeyPassphrase(
    String keyId,
    String? passphrase,
  ) async {
    return _impl.writeKeyPassphrase(keyId, passphrase);
  }

  static Future<void> deleteKeyPassphrase(String keyId) async {
    return _impl.deleteKeyPassphrase(keyId);
  }

  /// Migrates plaintext profile passwords into secure storage.
  ///
  /// Returns updated profile maps with `password` cleared when migrated.
  static Future<List<Map<String, dynamic>>> migrateProfilePasswords(
    List<Map<String, dynamic>> profiles,
  ) async {
    return _impl.migrateProfilePasswords(profiles);
  }

  /// Migrates plaintext key passphrases into secure storage.
  static Future<List<Map<String, dynamic>>> migrateKeyPassphrases(
    List<Map<String, dynamic>> keys,
  ) async {
    return _impl.migrateKeyPassphrases(keys);
  }

  /// Moves legacy plain-text keys from [settings] into secure storage.
  ///
  /// Returns `true` when keys were migrated and should be removed from settings.
  static Future<bool> migrateApiKeysFromSettings(
    Map<String, dynamic> settings,
  ) async {
    return _impl.migrateApiKeysFromSettings(settings);
  }

  static Future<void> importApiKeysFromBackup(
    Map<String, dynamic> settings,
  ) async {
    return _impl.importApiKeysFromBackup(settings);
  }

  static Map<String, dynamic> stripApiKeys(Map<String, dynamic> settings) {
    return _impl.stripApiKeys(settings);
  }
}

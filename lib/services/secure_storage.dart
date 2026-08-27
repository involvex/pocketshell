import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Low-level storage backend interface for testability.
abstract interface class SecureStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Adapter that wraps [FlutterSecureStorage] to implement [SecureStorageBackend].
class FlutterSecureStorageAdapter implements SecureStorageBackend {
  final FlutterSecureStorage _storage;

  const FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

abstract interface class SecureStorage {
  Future<String> readOpencodeZenApiKey();
  Future<String> readKiloApiKey();
  Future<void> writeOpencodeZenApiKey(String value);
  Future<void> writeKiloApiKey(String value);
  Future<String?> readProfilePassword(String profileId);
  Future<void> writeProfilePassword(String profileId, String? password);
  Future<void> deleteProfilePassword(String profileId);
  Future<String?> readKeyPassphrase(String keyId);
  Future<void> writeKeyPassphrase(String keyId, String? passphrase);
  Future<void> deleteKeyPassphrase(String keyId);
  Future<String?> readPrivateKey(String keyId);
  Future<void> writePrivateKey(String keyId, String? pem);
  Future<void> deletePrivateKey(String keyId);
  Future<List<Map<String, dynamic>>> migrateProfilePasswords(
    List<Map<String, dynamic>> profiles,
  );
  Future<List<Map<String, dynamic>>> migrateKeyPassphrases(
    List<Map<String, dynamic>> keys,
  );
  Future<List<Map<String, dynamic>>> migratePrivateKeys(
    List<Map<String, dynamic>> keys,
  );
  Future<bool> migrateApiKeysFromSettings(Map<String, dynamic> settings);
  Future<void> importApiKeysFromBackup(Map<String, dynamic> settings);
  Map<String, dynamic> stripApiKeys(Map<String, dynamic> settings);
}

class SecureStorageImpl implements SecureStorage {
  final SecureStorageBackend _storage;

  SecureStorageImpl({SecureStorageBackend? storage})
      : _storage = storage ?? const FlutterSecureStorageAdapter();

  static const String _opencodeZenApiKeyKey = 'opencode_zen_api_key';
  static const String _kiloApiKeyKey = 'kilo_api_key';
  static const String _profilePasswordPrefix = 'ssh_profile_password_';
  static const String _keyPassphrasePrefix = 'ssh_key_passphrase_';
  static const String _privateKeyPrefix = 'ssh_private_key_';

  static String _profilePasswordKey(String profileId) =>
      '$_profilePasswordPrefix$profileId';

  static String _keyPassphraseKey(String keyId) =>
      '$_keyPassphrasePrefix$keyId';

  static String _privateKeyKey(String keyId) => '$_privateKeyPrefix$keyId';

  Future<T?> _safeRead<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } on PlatformException {
      return null;
    }
  }

  Future<bool> _safeWrite(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } on PlatformException {
      // Silently fail on locked keyring (e.g., Linux headless)
      return false;
    }
  }

  Future<void> _safeDelete(Future<void> Function() delete) async {
    try {
      await delete();
    } on PlatformException {
      // Silently fail on locked keyring
    }
  }

  @override
  Future<String> readOpencodeZenApiKey() async {
    return (await _safeRead(() => _storage.read(key: _opencodeZenApiKeyKey))) ??
        '';
  }

  @override
  Future<String> readKiloApiKey() async {
    return (await _safeRead(() => _storage.read(key: _kiloApiKeyKey))) ?? '';
  }

  @override
  Future<void> writeOpencodeZenApiKey(String value) async {
    if (value.isEmpty) {
      await _safeDelete(() => _storage.delete(key: _opencodeZenApiKeyKey));
      return;
    }
    await _safeWrite(
        () => _storage.write(key: _opencodeZenApiKeyKey, value: value));
  }

  @override
  Future<void> writeKiloApiKey(String value) async {
    if (value.isEmpty) {
      await _safeDelete(() => _storage.delete(key: _kiloApiKeyKey));
      return;
    }
    await _safeWrite(() => _storage.write(key: _kiloApiKeyKey, value: value));
  }

  @override
  Future<String?> readProfilePassword(String profileId) async {
    return _safeRead(() => _storage.read(key: _profilePasswordKey(profileId)));
  }

  @override
  Future<void> writeProfilePassword(
    String profileId,
    String? password,
  ) async {
    final key = _profilePasswordKey(profileId);
    if (password == null || password.isEmpty) {
      await _safeDelete(() => _storage.delete(key: key));
      return;
    }
    await _safeWrite(() => _storage.write(key: key, value: password));
  }

  @override
  Future<void> deleteProfilePassword(String profileId) async {
    await _safeDelete(
        () => _storage.delete(key: _profilePasswordKey(profileId)));
  }

  @override
  Future<String?> readKeyPassphrase(String keyId) async {
    return _safeRead(() => _storage.read(key: _keyPassphraseKey(keyId)));
  }

  @override
  Future<void> writeKeyPassphrase(
    String keyId,
    String? passphrase,
  ) async {
    final key = _keyPassphraseKey(keyId);
    if (passphrase == null || passphrase.isEmpty) {
      await _safeDelete(() => _storage.delete(key: key));
      return;
    }
    await _safeWrite(() => _storage.write(key: key, value: passphrase));
  }

  @override
  Future<void> deleteKeyPassphrase(String keyId) async {
    await _safeDelete(() => _storage.delete(key: _keyPassphraseKey(keyId)));
  }

  @override
  Future<String?> readPrivateKey(String keyId) async {
    return _safeRead(() => _storage.read(key: _privateKeyKey(keyId)));
  }

  @override
  Future<void> writePrivateKey(
    String keyId,
    String? pem,
  ) async {
    final key = _privateKeyKey(keyId);
    if (pem == null || pem.isEmpty) {
      await _safeDelete(() => _storage.delete(key: key));
      return;
    }
    await _safeWrite(() => _storage.write(key: key, value: pem));
  }

  @override
  Future<void> deletePrivateKey(String keyId) async {
    await _safeDelete(() => _storage.delete(key: _privateKeyKey(keyId)));
  }

  @override
  Future<List<Map<String, dynamic>>> migrateProfilePasswords(
    List<Map<String, dynamic>> profiles,
  ) async {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final raw in profiles) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      final password = map['password'] as String?;
      if (id != null && password != null && password.isNotEmpty) {
        final success = await _safeWrite(() =>
            _storage.write(key: _profilePasswordKey(id), value: password));
        // Only clear after successful write (atomicity)
        if (success) {
          map['password'] = null;
          changed = true;
        }
      }
      out.add(map);
    }
    if (changed) {
      return out;
    }
    return List<Map<String, dynamic>>.from(profiles);
  }

  @override
  Future<List<Map<String, dynamic>>> migrateKeyPassphrases(
    List<Map<String, dynamic>> keys,
  ) async {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final raw in keys) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      final passphrase = map['passphrase'] as String?;
      if (id != null && passphrase != null && passphrase.isNotEmpty) {
        final success = await _safeWrite(() =>
            _storage.write(key: _keyPassphraseKey(id), value: passphrase));
        // Only clear after successful write (atomicity)
        if (success) {
          map['passphrase'] = null;
          changed = true;
        }
      }
      out.add(map);
    }
    if (changed) {
      return out;
    }
    return List<Map<String, dynamic>>.from(keys);
  }

  @override
  Future<List<Map<String, dynamic>>> migratePrivateKeys(
    List<Map<String, dynamic>> keys,
  ) async {
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final raw in keys) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String?;
      final privateKey = map['privateKey'] as String?;
      if (id != null && privateKey != null && privateKey.isNotEmpty) {
        final success = await _safeWrite(
            () => _storage.write(key: _privateKeyKey(id), value: privateKey));
        if (success) {
          map['privateKey'] = '';
          changed = true;
        }
      }
      out.add(map);
    }
    if (changed) {
      return out;
    }
    return List<Map<String, dynamic>>.from(keys);
  }

  @override
  Future<bool> migrateApiKeysFromSettings(
    Map<String, dynamic> settings,
  ) async {
    var migrated = false;
    final settingsCopy = Map<String, dynamic>.from(settings);

    final opencodeKey = settingsCopy['opencodeZenApiKey'] as String?;
    if (opencodeKey != null && opencodeKey.isNotEmpty) {
      await writeOpencodeZenApiKey(opencodeKey);
      settingsCopy.remove('opencodeZenApiKey');
      migrated = true;
    }

    final kiloKey = settingsCopy['kiloApiKey'] as String?;
    if (kiloKey != null && kiloKey.isNotEmpty) {
      await writeKiloApiKey(kiloKey);
      settingsCopy.remove('kiloApiKey');
      migrated = true;
    }

    if (migrated) {
      settings.clear();
      settings.addAll(settingsCopy);
    }

    return migrated;
  }

  @override
  Future<void> importApiKeysFromBackup(
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

  @override
  Map<String, dynamic> stripApiKeys(Map<String, dynamic> settings) {
    return Map<String, dynamic>.from(settings)
      ..remove('opencodeZenApiKey')
      ..remove('kiloApiKey');
  }
}

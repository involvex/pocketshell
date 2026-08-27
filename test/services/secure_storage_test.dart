import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/secure_storage.dart';

/// In-memory fake implementation of [SecureStorageBackend] for testing.
class FakeSecureStorageBackend implements SecureStorageBackend {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

/// A fake backend that throws PlatformException on write/delete
/// to simulate a locked keyring (e.g., Linux headless).
class FailingSecureStorageBackend implements SecureStorageBackend {
  @override
  Future<String?> read({required String key}) async {
    return null;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    throw PlatformException(code: 'KEYRING_LOCKED');
  }

  @override
  Future<void> delete({required String key}) async {
    throw PlatformException(code: 'KEYRING_LOCKED');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageImpl', () {
    late FakeSecureStorageBackend fakeStorage;
    late SecureStorageImpl storage;

    setUp(() {
      fakeStorage = FakeSecureStorageBackend();
      storage = SecureStorageImpl(storage: fakeStorage);
    });

    group('read/write OpencodeZen API key', () {
      test('readOpencodeZenApiKey returns empty string when not set', () async {
        final result = await storage.readOpencodeZenApiKey();
        expect(result, '');
      });

      test('readOpencodeZenApiKey returns stored value', () async {
        await fakeStorage.write(
            key: 'opencode_zen_api_key', value: 'test-key-123');
        final result = await storage.readOpencodeZenApiKey();
        expect(result, 'test-key-123');
      });

      test('writeOpencodeZenApiKey writes value', () async {
        await storage.writeOpencodeZenApiKey('new-key');
        final stored = await fakeStorage.read(key: 'opencode_zen_api_key');
        expect(stored, 'new-key');
      });

      test('writeOpencodeZenApiKey deletes when empty', () async {
        await fakeStorage.write(key: 'opencode_zen_api_key', value: 'existing');
        await storage.writeOpencodeZenApiKey('');
        final stored = await fakeStorage.read(key: 'opencode_zen_api_key');
        expect(stored, null);
      });
    });

    group('read/write Kilo API key', () {
      test('readKiloApiKey returns empty string when not set', () async {
        final result = await storage.readKiloApiKey();
        expect(result, '');
      });

      test('writeKiloApiKey writes value', () async {
        await storage.writeKiloApiKey('kilo-key');
        final stored = await fakeStorage.read(key: 'kilo_api_key');
        expect(stored, 'kilo-key');
      });

      test('writeKiloApiKey deletes when empty', () async {
        await fakeStorage.write(key: 'kilo_api_key', value: 'existing');
        await storage.writeKiloApiKey('');
        final stored = await fakeStorage.read(key: 'kilo_api_key');
        expect(stored, null);
      });
    });

    group('profile password operations', () {
      test('readProfilePassword returns null when not set', () async {
        final result = await storage.readProfilePassword('profile-1');
        expect(result, null);
      });

      test('readProfilePassword returns stored value', () async {
        await fakeStorage.write(
            key: 'ssh_profile_password_profile-1', value: 'secret-password');
        final result = await storage.readProfilePassword('profile-1');
        expect(result, 'secret-password');
      });

      test('writeProfilePassword writes value', () async {
        await storage.writeProfilePassword('profile-1', 'new-pass');
        final stored =
            await fakeStorage.read(key: 'ssh_profile_password_profile-1');
        expect(stored, 'new-pass');
      });

      test('writeProfilePassword deletes when null', () async {
        await fakeStorage.write(
            key: 'ssh_profile_password_profile-1', value: 'existing');
        await storage.writeProfilePassword('profile-1', null);
        final stored =
            await fakeStorage.read(key: 'ssh_profile_password_profile-1');
        expect(stored, null);
      });

      test('writeProfilePassword deletes when empty', () async {
        await fakeStorage.write(
            key: 'ssh_profile_password_profile-1', value: 'existing');
        await storage.writeProfilePassword('profile-1', '');
        final stored =
            await fakeStorage.read(key: 'ssh_profile_password_profile-1');
        expect(stored, null);
      });

      test('deleteProfilePassword calls delete', () async {
        await fakeStorage.write(
            key: 'ssh_profile_password_profile-1', value: 'existing');
        await storage.deleteProfilePassword('profile-1');
        final stored =
            await fakeStorage.read(key: 'ssh_profile_password_profile-1');
        expect(stored, null);
      });
    });

    group('key passphrase operations', () {
      test('readKeyPassphrase returns null when not set', () async {
        final result = await storage.readKeyPassphrase('key-1');
        expect(result, null);
      });

      test('writeKeyPassphrase writes value', () async {
        await storage.writeKeyPassphrase('key-1', 'passphrase');
        final stored = await fakeStorage.read(key: 'ssh_key_passphrase_key-1');
        expect(stored, 'passphrase');
      });

      test('writeKeyPassphrase deletes when null', () async {
        await fakeStorage.write(
            key: 'ssh_key_passphrase_key-1', value: 'existing');
        await storage.writeKeyPassphrase('key-1', null);
        final stored = await fakeStorage.read(key: 'ssh_key_passphrase_key-1');
        expect(stored, null);
      });
    });

    group('PlatformException handling (simulated)', () {
      test('migrateProfilePasswords continues on write failure', () async {
        final failingStorage = FailingSecureStorageBackend();
        final storage = SecureStorageImpl(storage: failingStorage);

        final profiles = <Map<String, dynamic>>[
          {'id': 'p1', 'password': 'pass1'},
          {'id': 'p2', 'password': 'pass2'},
        ];

        final result = await storage.migrateProfilePasswords(profiles);

        // Should return original profiles unchanged when write fails
        expect(result.length, 2);
        expect(result[0]['password'], 'pass1');
        expect(result[1]['password'], 'pass2');
      });
    });

    group('migrateProfilePasswords', () {
      test('migrates profiles with passwords', () async {
        final profiles = <Map<String, dynamic>>[
          {'id': 'p1', 'password': 'pass1'},
          {'id': 'p2', 'password': 'pass2'},
        ];

        final result = await storage.migrateProfilePasswords(profiles);

        expect(result.length, 2);
        expect(result[0]['password'], null);
        expect(result[1]['password'], null);

        final stored1 = await fakeStorage.read(key: 'ssh_profile_password_p1');
        final stored2 = await fakeStorage.read(key: 'ssh_profile_password_p2');
        expect(stored1, 'pass1');
        expect(stored2, 'pass2');
      });

      test('skips profiles without password', () async {
        final profiles = <Map<String, dynamic>>[
          {'id': 'p1', 'password': 'pass1'},
          {'id': 'p2'}, // no password
          {'id': 'p3', 'password': ''}, // empty password
        ];

        final result = await storage.migrateProfilePasswords(profiles);

        expect(result.length, 3);
        expect(result[0]['password'], null);
        expect(result[1]['password'], null);
        expect(result[2]['password'], '');

        final stored1 = await fakeStorage.read(key: 'ssh_profile_password_p1');
        expect(stored1, 'pass1');

        final stored2 = await fakeStorage.read(key: 'ssh_profile_password_p2');
        expect(stored2, null);

        final stored3 = await fakeStorage.read(key: 'ssh_profile_password_p3');
        expect(stored3, null);
      });

      test('returns copy when no changes', () async {
        final profiles = <Map<String, dynamic>>[
          {'id': 'p1'},
        ];

        final result = await storage.migrateProfilePasswords(profiles);

        expect(identical(result, profiles), false);
        expect(result.length, 1);
        expect(result[0]['id'], 'p1');
      });

      test('does not mutate input maps', () async {
        final original = <Map<String, dynamic>>[
          {'id': 'p1', 'password': 'pass1'},
        ];
        final originalCopy = List<Map<String, dynamic>>.from(original);

        await storage.migrateProfilePasswords(original);

        // Original should be unchanged
        expect(original[0]['password'], 'pass1');
        expect(original[0]['password'], originalCopy[0]['password']);
      });
    });

    group('migrateKeyPassphrases', () {
      test('migrates keys with passphrases', () async {
        final keys = <Map<String, dynamic>>[
          {'id': 'k1', 'passphrase': 'phrase1'},
          {'id': 'k2', 'passphrase': 'phrase2'},
        ];

        final result = await storage.migrateKeyPassphrases(keys);

        expect(result.length, 2);
        expect(result[0]['passphrase'], null);
        expect(result[1]['passphrase'], null);

        final stored1 = await fakeStorage.read(key: 'ssh_key_passphrase_k1');
        final stored2 = await fakeStorage.read(key: 'ssh_key_passphrase_k2');
        expect(stored1, 'phrase1');
        expect(stored2, 'phrase2');
      });
    });

    group('migrateApiKeysFromSettings', () {
      test('migrates opencode key from settings', () async {
        final settings = <String, dynamic>{
          'opencodeZenApiKey': 'opencode-key',
        };

        final migrated = await storage.migrateApiKeysFromSettings(settings);

        expect(migrated, true);
        expect(settings.containsKey('opencodeZenApiKey'), false);

        final stored = await fakeStorage.read(key: 'opencode_zen_api_key');
        expect(stored, 'opencode-key');
      });

      test('migrates kilo key from settings', () async {
        final settings = <String, dynamic>{
          'kiloApiKey': 'kilo-key',
        };

        final migrated = await storage.migrateApiKeysFromSettings(settings);

        expect(migrated, true);
        expect(settings.containsKey('kiloApiKey'), false);

        final stored = await fakeStorage.read(key: 'kilo_api_key');
        expect(stored, 'kilo-key');
      });

      test('migrates both keys', () async {
        final settings = <String, dynamic>{
          'opencodeZenApiKey': 'opencode-key',
          'kiloApiKey': 'kilo-key',
        };

        final migrated = await storage.migrateApiKeysFromSettings(settings);

        expect(migrated, true);
        expect(settings.containsKey('opencodeZenApiKey'), false);
        expect(settings.containsKey('kiloApiKey'), false);
      });

      test('returns false when no keys to migrate', () async {
        final settings = <String, dynamic>{'theme': 'dark'};

        final migrated = await storage.migrateApiKeysFromSettings(settings);

        expect(migrated, false);
        expect(settings['theme'], 'dark');
      });

      test('handles empty string keys', () async {
        final settings = <String, dynamic>{
          'opencodeZenApiKey': '',
          'kiloApiKey': '',
        };

        final migrated = await storage.migrateApiKeysFromSettings(settings);

        expect(migrated, false);
        final opencodeStored =
            await fakeStorage.read(key: 'opencode_zen_api_key');
        final kiloStored = await fakeStorage.read(key: 'kilo_api_key');
        expect(opencodeStored, null);
        expect(kiloStored, null);
      });
    });

    group('importApiKeysFromBackup', () {
      test('imports both keys from backup', () async {
        final settings = <String, dynamic>{
          'opencodeZenApiKey': 'opencode-key',
          'kiloApiKey': 'kilo-key',
        };

        await storage.importApiKeysFromBackup(settings);

        expect(settings.containsKey('opencodeZenApiKey'), false);
        expect(settings.containsKey('kiloApiKey'), false);

        final opencodeStored =
            await fakeStorage.read(key: 'opencode_zen_api_key');
        final kiloStored = await fakeStorage.read(key: 'kilo_api_key');
        expect(opencodeStored, 'opencode-key');
        expect(kiloStored, 'kilo-key');
      });

      test('handles missing keys in backup', () async {
        final settings = <String, dynamic>{};

        await storage.importApiKeysFromBackup(settings);

        // Should not throw
      });
    });

    group('stripApiKeys', () {
      test('removes both API keys from settings copy', () {
        final settings = <String, dynamic>{
          'opencodeZenApiKey': 'key1',
          'kiloApiKey': 'key2',
          'theme': 'dark',
        };

        final stripped = storage.stripApiKeys(settings);

        expect(stripped['opencodeZenApiKey'], isNull);
        expect(stripped['kiloApiKey'], isNull);
        expect(stripped['theme'], 'dark');
        // Original unchanged
        expect(settings['opencodeZenApiKey'], 'key1');
      });
    });
  });
}

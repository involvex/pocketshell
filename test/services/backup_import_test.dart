import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/services/backup_service.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/secure_storage.dart';
import 'package:ssh_app/services/secure_storage_service.dart';

class _MemoryBackend implements SecureStorageBackend {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConfigService.init();
    backend = _MemoryBackend();
    SecureStorageService.debugImpl = SecureStorageImpl(storage: backend);
  });

  tearDown(SecureStorageService.debugResetImpl);

  test('applyImportedData stores profile secrets outside prefs', () async {
    await BackupService.applyImportedData(<String, dynamic>{
      'version': 1,
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p1',
          'name': 'win',
          'host': '10.0.0.5',
          'username': 'lukas',
          'password': 'ssh-secret',
          'agentPassword': 'agent-secret',
        },
      ],
    });

    final stored = await ConfigService.getProfiles();
    expect(stored, hasLength(1));
    expect(stored.single['password'], isNull);
    expect(stored.single.containsKey('agentPassword'), isFalse);
    expect(backend.store['ssh_profile_password_p1'], 'ssh-secret');
    expect(backend.store['ssh_agent_password_p1'], 'agent-secret');
  });

  test('applyImportedData drops inline PEM from profile JSON', () async {
    await BackupService.applyImportedData(<String, dynamic>{
      'version': 1,
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p2',
          'name': 'win',
          'host': 'h',
          'username': 'u',
          'privateKey':
              '-----BEGIN OPENSSH PRIVATE KEY-----\nsecret\n-----END OPENSSH PRIVATE KEY-----',
        },
      ],
    });

    final stored = await ConfigService.getProfiles();
    expect(stored.single.containsKey('privateKey'), isFalse);
  });
}

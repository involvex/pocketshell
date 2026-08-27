import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/services/config_repository.dart';

void main() {
  group('FakeConfigRepository Tests', () {
    late FakeConfigRepository repo;

    setUp(() {
      repo = FakeConfigRepository();
    });

    test('profiles roundtrip', () async {
      expect(await repo.getProfiles(), isEmpty);
      final profiles = [
        {
          'id': '1',
          'name': 'Test',
          'host': 'localhost',
          'port': 22,
          'username': 'user'
        }
      ];
      await repo.saveProfiles(profiles);
      final loaded = await repo.getProfiles();
      expect(loaded, equals(profiles));
    });

    test('last session roundtrip', () async {
      expect(await repo.getLastSession(), isNull);
      final session = {
        'id': '1',
        'name': 'Test',
        'host': 'localhost',
        'port': 22,
        'username': 'user'
      };
      await repo.saveLastSession(session);
      final loaded = await repo.getLastSession();
      expect(loaded, equals(session));
    });

    test('settings roundtrip', () async {
      final settings = await repo.getSettings();
      expect(settings, isNotEmpty);
      settings['theme'] = 'light';
      await repo.saveSettings(settings);
      final loaded = await repo.getSettings();
      expect(loaded['theme'], equals('light'));
    });

    test('ssh keys roundtrip', () async {
      expect(await repo.getSSHKeys(), isEmpty);
      final keys = [
        {
          'id': 'k1',
          'name': 'Key 1',
          'keyType': 2,
          'publicKey': 'pub',
          'createdAt': DateTime.now().toIso8601String()
        }
      ];
      await repo.saveSSHKeys(keys);
      final loaded = await repo.getSSHKeys();
      expect(loaded.length, equals(1));
      expect(loaded.first['name'], equals('Key 1'));
    });

    test('snippets roundtrip', () async {
      expect(await repo.getSnippets(), isEmpty);
      final snippets = [
        {
          'id': 's1',
          'name': 'Snippet 1',
          'content': 'ls -la',
          'category': 'General'
        }
      ];
      await repo.saveSnippets(snippets);
      final loaded = await repo.getSnippets();
      expect(loaded.length, equals(1));
    });

    test('agent last directory roundtrip', () async {
      expect(await repo.getAgentLastDirectory(), isNull);
      await repo.saveAgentLastDirectory('/path/to/project');
      expect(await repo.getAgentLastDirectory(), equals('/path/to/project'));
    });

    test('sftp state roundtrip', () async {
      expect(await repo.getSftpSortField(), equals('name'));
      await repo.saveSftpSortField('size');
      expect(await repo.getSftpSortField(), equals('size'));

      expect(await repo.getSftpSortAscending(), isTrue);
      await repo.saveSftpSortAscending(false);
      expect(await repo.getSftpSortAscending(), isFalse);

      expect(await repo.getSftpLastPath(), isNull);
      await repo.saveSftpLastPath('/home');
      expect(await repo.getSftpLastPath(), equals('/home'));
      await repo.clearSftpLastPath();
      expect(await repo.getSftpLastPath(), isNull);
    });

    test('clearAll clears store', () async {
      await repo.saveAgentLastDirectory('/test');
      await repo.clearAll();
      expect(await repo.getAgentLastDirectory(), isNull);
    });
  });
}

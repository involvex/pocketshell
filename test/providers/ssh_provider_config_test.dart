import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/config_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('SSHProvider Config Tests', () {
    late FakeConfigRepository fakeRepo;
    late SSHProvider provider;

    setUp(() {
      fakeRepo = FakeConfigRepository();
      provider = SSHProvider(config: fakeRepo);
    });

    test('loadConfig loads profiles and last session from repository',
        () async {
      final profile = SSHProfile(
        name: 'Server 1',
        host: '192.168.1.50',
        port: 22,
        username: 'ubuntu',
      );

      await fakeRepo.saveProfiles([profile.toJson()]);
      await fakeRepo.saveLastSession(profile.toJson());

      await provider.loadConfig();

      expect(provider.profiles.length, equals(1));
      expect(provider.profiles.first.name, equals('Server 1'));
      expect(provider.profiles.first.host, equals('192.168.1.50'));
      expect(provider.lastSession, isNotNull);
      expect(provider.lastSession!.name, equals('Server 1'));
    });

    test('saveProfile persists profile through repository', () async {
      final profile = SSHProfile(
        name: 'Server 2',
        host: '10.0.0.1',
        port: 2222,
        username: 'root',
      );

      await provider.saveProfile(profile);

      final storedProfiles = await fakeRepo.getProfiles();
      expect(storedProfiles.length, equals(1));
      expect(storedProfiles.first['name'], equals('Server 2'));
      expect(storedProfiles.first['port'], equals(2222));
    });

    test('deleteProfile removes profile from repository', () async {
      final profile = SSHProfile(
        id: 'p1',
        name: 'Server 3',
        host: '10.0.0.2',
        port: 22,
        username: 'admin',
      );

      await provider.saveProfile(profile);
      expect(provider.profiles.length, equals(1));

      await provider.deleteProfile('p1');
      expect(provider.profiles, isEmpty);

      final storedProfiles = await fakeRepo.getProfiles();
      expect(storedProfiles, isEmpty);
    });
  });
}

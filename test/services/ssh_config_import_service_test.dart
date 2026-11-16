import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/ssh_config_import_service.dart';

void main() {
  group('SshConfigImportService.mergeIntoProfiles', () {
    test('creates and updates without overwriting passwords', () {
      const importer = SshConfigImportService();
      final existing = <SSHProfile>[
        SSHProfile(
          id: 'keep-id',
          name: 'Old Name',
          host: '192.168.1.10',
          port: 2222,
          username: 'lukas',
          password: '<<keep-me>>',
        ),
      ];

      const raw = '''
Host lab
  HostName 192.168.1.10
  User lukas
  Port 2222

Host other
  HostName 10.0.0.2
  User admin
''';

      final merged = importer.mergeIntoProfiles(
        existing: existing,
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      expect(merged.result.created, 1);
      expect(merged.result.updated, 1);
      expect(merged.profiles, hasLength(2));

      final updated = merged.profiles.firstWhere((p) => p.id == 'keep-id');
      expect(updated.name, 'lab');
      expect(updated.password, '<<keep-me>>');

      final created = merged.profiles.firstWhere((p) => p.name == 'other');
      expect(created.host, '10.0.0.2');
      expect(created.username, 'admin');
      expect(created.password, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/identity_file_path.dart';

void main() {
  group('identityFileCandidates', () {
    test('expands tilde from Windows config home', () {
      final paths = identityFileCandidates(
        identityFile: '~/.ssh/id_ed25519',
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
      );

      expect(paths.first, 'C:/Users/lukas/.ssh/id_ed25519');
    });

    test('expands tilde from POSIX config home', () {
      final paths = identityFileCandidates(
        identityFile: '~/.ssh/id_rsa',
        configPath: '/home/lukas/.ssh/config',
        username: 'lukas',
      );

      expect(paths.first, '/home/lukas/.ssh/id_rsa');
    });

    test('joins relative paths to the config directory', () {
      final paths = identityFileCandidates(
        identityFile: 'id_ed25519',
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
      );

      expect(paths, <String>['C:/Users/lukas/.ssh/id_ed25519']);
    });

    test('keeps absolute Windows and POSIX paths', () {
      expect(
        identityFileCandidates(
          identityFile: r'C:\Users\shared\keys\lab',
          configPath: 'C:/Users/lukas/.ssh/config',
          username: 'lukas',
        ),
        <String>['C:/Users/shared/keys/lab'],
      );
      expect(
        identityFileCandidates(
          identityFile: '/etc/ssh/user_keys/lab',
          configPath: '/home/lukas/.ssh/config',
          username: 'lukas',
        ),
        <String>['/etc/ssh/user_keys/lab'],
      );
    });
  });

  group('homeDirectoryFromSshConfigPath', () {
    test('returns parent of .ssh', () {
      expect(
        homeDirectoryFromSshConfigPath('C:/Users/lukas/.ssh/config'),
        'C:/Users/lukas',
      );
      expect(
        homeDirectoryFromSshConfigPath('/home/lukas/.ssh/config'),
        '/home/lukas',
      );
    });

    test('returns null when path is not under .ssh', () {
      expect(homeDirectoryFromSshConfigPath('/etc/ssh/ssh_config'), isNull);
    });
  });

  group('identityFileBaseName', () {
    test('returns the last segment', () {
      expect(identityFileBaseName('C:/Users/lukas/.ssh/id_ed25519'), 'id_ed25519');
      expect(identityFileBaseName('id_rsa'), 'id_rsa');
    });
  });
}

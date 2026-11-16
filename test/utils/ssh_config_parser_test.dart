import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/ssh_config_parser.dart';

void main() {
  group('parseSshConfig', () {
    test('parses multiple hosts with HostName Port User defaults', () {
      const raw = '''
# comment
Host lab
  HostName 192.168.1.10
  User lukas
  Port 2222
  IdentityFile ~/.ssh/id_ed25519

Host bare
  User admin

Host *
  Compression yes
''';
      final result = parseSshConfig(raw);
      expect(result.hosts, hasLength(2));

      final lab = result.hosts.first;
      expect(lab.alias, 'lab');
      expect(lab.hostName, '192.168.1.10');
      expect(lab.user, 'lukas');
      expect(lab.port, 2222);
      expect(lab.identityFile, '~/.ssh/id_ed25519');

      final bare = result.hosts[1];
      expect(bare.alias, 'bare');
      expect(bare.hostName, 'bare');
      expect(bare.user, 'admin');
      expect(bare.port, 22);
    });

    test('records skipped ProxyJump and does not leak secrets', () {
      const raw = '''
Host jumpbox
  HostName bastion.example
  User ops
  ProxyJump jump@gateway
  ProxyCommand ssh -W %h:%p gateway
  PasswordAuthentication yes
''';
      final result = parseSshConfig(raw);
      expect(result.hosts, hasLength(1));
      final host = result.hosts.single;
      expect(host.skippedDirectives, contains('ProxyJump'));
      expect(host.skippedDirectives, contains('ProxyCommand'));
      final encoded = '${host.alias}|${host.hostName}|${host.user}|'
          '${host.port}|${host.identityFile}|${host.skippedDirectives}';
      expect(encoded.contains('password'), isFalse);
      expect(encoded.toLowerCase().contains('secret'), isFalse);
    });

    test('skips wildcard Host patterns', () {
      const raw = '''
Host *.internal
  User nobody

Host real
  HostName 10.0.0.5
''';
      final result = parseSshConfig(raw);
      expect(result.hosts, hasLength(1));
      expect(result.hosts.single.alias, 'real');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/utils/jump_host_utils.dart';

void main() {
  group('createsJumpCycle', () {
    test('rejects self-jump', () {
      final profiles = <SSHProfile>[
        SSHProfile(id: 'a', name: 'A', host: '1', username: 'u'),
      ];
      expect(createsJumpCycle(profiles, 'a', 'a'), isTrue);
    });

    test('rejects A→B→A', () {
      final profiles = <SSHProfile>[
        SSHProfile(
          id: 'a',
          name: 'A',
          host: '1',
          username: 'u',
          jumpProfileId: 'b',
        ),
        SSHProfile(
          id: 'b',
          name: 'B',
          host: '2',
          username: 'u',
          jumpProfileId: 'a',
        ),
      ];
      expect(createsJumpCycle(profiles, 'a', 'b'), isTrue);
    });

    test('allows A→B when B is direct', () {
      final profiles = <SSHProfile>[
        SSHProfile(id: 'a', name: 'A', host: '1', username: 'u'),
        SSHProfile(id: 'b', name: 'B', host: '2', username: 'u'),
      ];
      expect(createsJumpCycle(profiles, 'a', 'b'), isFalse);
    });

    test('allows clearing jump', () {
      expect(createsJumpCycle(const <SSHProfile>[], 'a', null), isFalse);
      expect(createsJumpCycle(const <SSHProfile>[], 'a', ''), isFalse);
    });
  });

  group('resolveProxyJumpProfileId', () {
    test('matches Host alias name', () {
      final profiles = <SSHProfile>[
        SSHProfile(
          id: 'jump-id',
          name: 'bastion',
          host: '10.0.0.1',
          username: 'ops',
        ),
      ];
      expect(
        resolveProxyJumpProfileId(profiles: profiles, proxyJump: 'bastion'),
        'jump-id',
      );
    });

    test('matches user@host:port', () {
      final profiles = <SSHProfile>[
        SSHProfile(
          id: 'gw',
          name: 'gw',
          host: 'gateway.example',
          port: 2222,
          username: 'jump',
        ),
      ];
      expect(
        resolveProxyJumpProfileId(
          profiles: profiles,
          proxyJump: 'jump@gateway.example:2222',
        ),
        'gw',
      );
    });

    test('returns null when unresolved', () {
      expect(
        resolveProxyJumpProfileId(
          profiles: const <SSHProfile>[],
          proxyJump: 'missing',
        ),
        isNull,
      );
    });
  });

  group('parseProxyJumpToken', () {
    test('parses user@host:port', () {
      final parsed = parseProxyJumpToken('ops@bastion:2222');
      expect(parsed.user, 'ops');
      expect(parsed.aliasOrHost, 'bastion');
      expect(parsed.port, 2222);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';

void main() {
  group('SSHProfile agent auth', () {
    test('defaults agentUsername to opencode', () {
      final profile = SSHProfile(
        name: 'win',
        host: '192.168.1.1',
        username: 'Lukas',
      );
      expect(profile.agentUsername, 'opencode');
      expect(profile.effectiveAgentUsername, 'opencode');
      expect(profile.allowSelfSignedCerts, isFalse);
    });

    test('effectiveAgentUsername falls back when empty', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        agentUsername: '',
      );
      expect(profile.effectiveAgentUsername, 'opencode');
    });

    test('effectiveAgentPassword prefers agentPassword', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        password: '<<ssh-fallback>>',
        agentPassword: '<<agent-override>>',
      );
      expect(profile.effectiveAgentPassword, '<<agent-override>>');
    });

    test('effectiveAgentPassword falls back to SSH password', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        password: '<<ssh-fallback>>',
      );
      expect(profile.effectiveAgentPassword, '<<ssh-fallback>>');
    });

    test('toJson omits agentPassword unless includePassword', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        agentUsername: 'opencode',
        agentPassword: '<<agent-override>>',
      );
      expect(profile.toJson().containsKey('agentPassword'), isFalse);
      expect(profile.toJson().containsKey('agentUsername'), isTrue);
      expect(
        profile.toJson(includePassword: true)['agentPassword'],
        '<<agent-override>>',
      );
    });

    test('fromJson round-trips agentUsername and self-signed flag', () {
      final profile = SSHProfile.fromJson(<String, dynamic>{
        'id': 'id-1',
        'name': 'n',
        'host': 'h',
        'username': 'u',
        'agentUsername': 'custom',
        'agentPort': 4000,
        'useHttps': true,
        'allowSelfSignedCerts': true,
      });
      expect(profile.agentUsername, 'custom');
      expect(profile.agentPort, 4000);
      expect(profile.useHttps, isTrue);
      expect(profile.allowSelfSignedCerts, isTrue);
    });
  });
}

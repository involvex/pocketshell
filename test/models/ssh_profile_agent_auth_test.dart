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
        password: 'ssh-pass',
        agentPassword: 'serve-pass',
      );
      expect(profile.effectiveAgentPassword, 'serve-pass');
    });

    test('effectiveAgentPassword falls back to SSH password', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        password: 'ssh-pass',
      );
      expect(profile.effectiveAgentPassword, 'ssh-pass');
    });

    test('toJson omits agentPassword unless includePassword', () {
      final profile = SSHProfile(
        name: 'win',
        host: 'h',
        username: 'Lukas',
        agentUsername: 'opencode',
        agentPassword: 'secret',
      );
      expect(profile.toJson().containsKey('agentPassword'), isFalse);
      expect(profile.toJson().containsKey('agentUsername'), isTrue);
      expect(profile.toJson(includePassword: true)['agentPassword'], 'secret');
    });

    test('fromJson round-trips agentUsername', () {
      final profile = SSHProfile.fromJson(<String, dynamic>{
        'id': 'id-1',
        'name': 'n',
        'host': 'h',
        'username': 'u',
        'agentUsername': 'custom',
        'agentPort': 4000,
      });
      expect(profile.agentUsername, 'custom');
      expect(profile.agentPort, 4000);
    });
  });
}

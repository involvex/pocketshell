import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/opencode_remote_config_service.dart';

void main() {
  test('probeDirsFor prefers Windows user OpenCode paths', () {
    final profile = SSHProfile(
      name: 'win',
      host: '192.168.1.10',
      port: 22,
      username: 'lukas',
    );

    expect(
      OpenCodeRemoteConfigService.probeDirsFor(profile),
      <String>[
        'C:/Users/lukas/.config/opencode',
        'C:/Users/lukas/AppData/Roaming/opencode',
      ],
    );
  });
}

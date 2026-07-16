import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/utils/session_manager.dart';

void main() {
  test('SSHProfile persists sessionManager', () {
    final profile = SSHProfile(
      name: 'win',
      host: '10.0.0.1',
      username: 'lukas',
      sessionManager: SessionManager.tmux,
    );

    final restored = SSHProfile.fromJson(profile.toJson());
    expect(restored.sessionManager, SessionManager.tmux);
  });

  test('SSHProfile defaults sessionManager to none', () {
    final restored = SSHProfile.fromJson(<String, dynamic>{
      'id': 'abc',
      'name': 'legacy',
      'host': 'localhost',
      'username': 'user',
    });
    expect(restored.sessionManager, SessionManager.none);
  });
}

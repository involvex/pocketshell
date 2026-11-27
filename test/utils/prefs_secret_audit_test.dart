import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/prefs_secret_audit.dart';

void main() {
  test('key id in privateKey is not treated as a secret', () {
    expect(
      mapListContainsLegacySecrets(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'p', 'privateKey': 'key-uuid'},
      ]),
      isFalse,
    );
  });

  test('password and PEM are secrets', () {
    expect(
      mapListContainsLegacySecrets(<Map<String, dynamic>>[
        <String, dynamic>{'password': 'x'},
      ]),
      isTrue,
    );
    expect(
      mapListContainsLegacySecrets(<Map<String, dynamic>>[
        <String, dynamic>{
          'privateKey': '-----BEGIN OPENSSH PRIVATE KEY-----\n',
        },
      ]),
      isTrue,
    );
  });
}

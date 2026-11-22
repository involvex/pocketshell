import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ssh_key.dart';

void main() {
  test('toJson omits private key and passphrase by default', () {
    final key = SSHKey(
      name: 'test',
      keyType: SSHKeyType.ed25519,
      publicKey: 'ssh-ed25519 AAAA',
      privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----\nsecret\n-----END OPENSSH PRIVATE KEY-----',
      passphrase: 'hunter2',
    );

    final json = key.toJson();
    expect(json.containsKey('privateKey'), isFalse);
    expect(json.containsKey('passphrase'), isFalse);
    expect(json['publicKey'], 'ssh-ed25519 AAAA');
  });

  test('toJson can include secrets only when explicitly requested', () {
    final key = SSHKey(
      name: 'test',
      keyType: SSHKeyType.ed25519,
      publicKey: 'ssh-ed25519 AAAA',
      privateKey: 'PRIVATE',
      passphrase: 'secret',
    );

    final json = key.toJson(
      includePrivateKey: true,
      includePassphrase: true,
    );
    expect(json['privateKey'], 'PRIVATE');
    expect(json['passphrase'], 'secret');
  });
}

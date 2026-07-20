import 'package:uuid/uuid.dart';

enum SSHKeyType {
  rsa2048,
  rsa4096,
  ed25519,
  ecdsa256,
  ecdsa384,
  ecdsa521,
}

extension SSHKeyTypeExtension on SSHKeyType {
  String get displayName {
    switch (this) {
      case SSHKeyType.rsa2048:
        return 'RSA 2048';
      case SSHKeyType.rsa4096:
        return 'RSA 4096';
      case SSHKeyType.ed25519:
        return 'Ed25519';
      case SSHKeyType.ecdsa256:
        return 'ECDSA 256';
      case SSHKeyType.ecdsa384:
        return 'ECDSA 384';
      case SSHKeyType.ecdsa521:
        return 'ECDSA 521';
    }
  }

  String get algorithm {
    switch (this) {
      case SSHKeyType.rsa2048:
      case SSHKeyType.rsa4096:
        return 'RSA';
      case SSHKeyType.ed25519:
        return 'Ed25519';
      case SSHKeyType.ecdsa256:
      case SSHKeyType.ecdsa384:
      case SSHKeyType.ecdsa521:
        return 'ECDSA';
    }
  }

  int get bitSize {
    switch (this) {
      case SSHKeyType.rsa2048:
        return 2048;
      case SSHKeyType.rsa4096:
        return 4096;
      case SSHKeyType.ed25519:
        return 256;
      case SSHKeyType.ecdsa256:
        return 256;
      case SSHKeyType.ecdsa384:
        return 384;
      case SSHKeyType.ecdsa521:
        return 521;
    }
  }
}

class SSHKey {
  final String id;
  final String name;
  final SSHKeyType keyType;
  final String publicKey;
  final String privateKey;
  final String? passphrase;
  final DateTime createdAt;

  SSHKey({
    required this.name,
    required this.keyType,
    required this.publicKey,
    required this.privateKey,
    String? id,
    DateTime? createdAt,
    this.passphrase,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  SSHKey.name(this.name, this.keyType, this.publicKey, this.privateKey,
      {this.passphrase, DateTime? createdAt, String? id})
      : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Serializes key material. Passphrases are stored via SecureStorageService.
  Map<String, dynamic> toJson({bool includePassphrase = false}) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'keyType': keyType.index,
      'publicKey': publicKey,
      'privateKey': privateKey,
      if (includePassphrase) 'passphrase': passphrase,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SSHKey.fromJson(Map<String, dynamic> json) {
    return SSHKey(
      id: json['id'] as String,
      name: json['name'] as String,
      keyType: SSHKeyType.values[json['keyType'] as int],
      publicKey: json['publicKey'] as String,
      privateKey: json['privateKey'] as String,
      passphrase: json['passphrase'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'package:ssh_app/models/ssh_key.dart';
import 'package:ssh_app/utils/ssh_auth_utils.dart';

/// Outcome of importing a PEM private key without a passphrase prompt.
enum PemKeyImportFailure {
  notPem,
  encrypted,
  parseFailed,
  unsupportedType,
}

/// Result of [tryImportUnencryptedPemKey].
class PemKeyImportResult {
  const PemKeyImportResult._({this.key, this.failure});

  const PemKeyImportResult.ok(SSHKey key) : this._(key: key);

  const PemKeyImportResult.failed(PemKeyImportFailure failure)
      : this._(failure: failure);

  final SSHKey? key;
  final PemKeyImportFailure? failure;

  bool get isOk => key != null;
}

/// Imports an unencrypted OpenSSH/PEM private key into an [SSHKey].
///
/// Encrypted PEMs are rejected (no passphrase UI on config import). Never logs
/// PEM contents.
PemKeyImportResult tryImportUnencryptedPemKey(
  String pem, {
  required String name,
}) {
  if (!looksLikePemPrivateKey(pem)) {
    return const PemKeyImportResult.failed(PemKeyImportFailure.notPem);
  }

  try {
    if (SSHKeyPair.isEncryptedPem(pem)) {
      return const PemKeyImportResult.failed(PemKeyImportFailure.encrypted);
    }
  } catch (_) {
    // Some PEMs throw on encryption probe; continue to fromPem.
  }

  late final List<SSHKeyPair> pairs;
  try {
    pairs = SSHKeyPair.fromPem(pem);
  } catch (_) {
    return const PemKeyImportResult.failed(PemKeyImportFailure.parseFailed);
  }
  if (pairs.isEmpty) {
    return const PemKeyImportResult.failed(PemKeyImportFailure.parseFailed);
  }

  final pair = pairs.first;
  final algorithm = pair.type;
  final keyType = sshKeyTypeForAlgorithm(algorithm);
  if (keyType == null) {
    return const PemKeyImportResult.failed(
      PemKeyImportFailure.unsupportedType,
    );
  }

  final encoded = pair.toPublicKey().encode();
  final publicLine = '$algorithm ${base64Encode(encoded)}';

  return PemKeyImportResult.ok(
    SSHKey(
      name: name,
      keyType: keyType,
      publicKey: publicLine,
      privateKey: pem.trim(),
    ),
  );
}

/// Maps an SSH algorithm name to [SSHKeyType], or null when unsupported.
SSHKeyType? sshKeyTypeForAlgorithm(String type) {
  switch (type) {
    case 'ssh-ed25519':
      return SSHKeyType.ed25519;
    case 'ssh-rsa':
      return SSHKeyType.rsa2048;
    case 'ecdsa-sha2-nistp256':
      return SSHKeyType.ecdsa256;
    case 'ecdsa-sha2-nistp384':
      return SSHKeyType.ecdsa384;
    case 'ecdsa-sha2-nistp521':
      return SSHKeyType.ecdsa521;
    default:
      return null;
  }
}

/// Human-readable reason for a failed PEM import (safe for UI / hints).
String pemKeyImportFailureMessage(PemKeyImportFailure failure) {
  switch (failure) {
    case PemKeyImportFailure.notPem:
      return 'not an OpenSSH/PEM private key';
    case PemKeyImportFailure.encrypted:
      return 'passphrase-protected (import manually in Key Manager)';
    case PemKeyImportFailure.parseFailed:
      return 'could not parse private key';
    case PemKeyImportFailure.unsupportedType:
      return 'unsupported key algorithm';
  }
}

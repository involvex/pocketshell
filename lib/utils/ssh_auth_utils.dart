import 'package:dartssh2/dartssh2.dart';

import 'package:ssh_app/models/ssh_key.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/secure_storage_service.dart';

/// Resolves dartssh2 identities and password handlers for a profile.
class SshAuthMaterial {
  const SshAuthMaterial({
    this.identities,
    this.password,
  });

  final List<SSHKeyPair>? identities;
  final String? password;

  bool get hasKeyAuth => identities != null && identities!.isNotEmpty;

  bool get hasPasswordAuth => password != null && password!.isNotEmpty;
}

bool looksLikePemPrivateKey(String value) {
  final trimmed = value.trimLeft();
  return trimmed.startsWith('-----BEGIN') && trimmed.contains('PRIVATE KEY');
}

/// Loads auth material for [profile].
///
/// [SSHProfile.privateKey] may be a PEM blob or an [SSHKey.id] reference.
Future<SshAuthMaterial> resolveSshAuthMaterial(SSHProfile profile) async {
  final password = await _resolvePassword(profile);
  final identities = await _resolveIdentities(profile);
  return SshAuthMaterial(identities: identities, password: password);
}

Future<String?> _resolvePassword(SSHProfile profile) async {
  final fromSecure = await SecureStorageService.readProfilePassword(profile.id);
  if (fromSecure != null && fromSecure.isNotEmpty) {
    return fromSecure;
  }
  final inline = profile.password;
  if (inline != null && inline.isNotEmpty) {
    return inline;
  }
  return null;
}

Future<List<SSHKeyPair>?> _resolveIdentities(SSHProfile profile) async {
  final ref = profile.privateKey?.trim();
  if (ref == null || ref.isEmpty) {
    return null;
  }

  String? pem;
  String? passphrase;

  if (looksLikePemPrivateKey(ref)) {
    pem = ref;
  } else {
    final keys = await ConfigService.getSSHKeys();
    Map<String, dynamic>? match;
    for (final raw in keys) {
      if (raw['id'] == ref) {
        match = raw;
        break;
      }
    }
    if (match == null) {
      return null;
    }
    final key = SSHKey.fromJson(match);
    pem = key.privateKey;
    passphrase = await SecureStorageService.readKeyPassphrase(key.id) ??
        key.passphrase;
  }

  if (pem.isEmpty) {
    return null;
  }

  try {
    return SSHKeyPair.fromPem(pem, passphrase);
  } catch (_) {
    if (passphrase != null && passphrase.isNotEmpty) {
      rethrow;
    }
    return SSHKeyPair.fromPem(pem);
  }
}

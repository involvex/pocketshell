/// True when SharedPreferences JSON still holds secrets that belong in
/// secure storage (failed migration, legacy import, inline PEM).
bool mapListContainsLegacySecrets(List<Map<String, dynamic>> items) {
  for (final map in items) {
    if (_nonEmptySecret(map['password']) ||
        _nonEmptySecret(map['agentPassword']) ||
        _nonEmptySecret(map['passphrase'])) {
      return true;
    }
    final privateKey = map['privateKey'];
    if (privateKey is String &&
        privateKey.trimLeft().startsWith('-----BEGIN')) {
      return true;
    }
  }
  return false;
}

bool _nonEmptySecret(Object? value) => value is String && value.isNotEmpty;

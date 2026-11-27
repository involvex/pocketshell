/// Strips credentials and PEM blobs from exception text before logs / UI.
String redactErrorForDisplay(Object error) {
  var text = error.toString();
  if (text.isEmpty) {
    return 'Unknown error';
  }

  // HTTP Basic / Bearer tokens in Dio or custom messages.
  text = text.replaceAllMapped(
    RegExp(r'(Basic\s+)[A-Za-z0-9+/=]+', caseSensitive: false),
    (Match m) => '${m[1]}***',
  );
  text = text.replaceAllMapped(
    RegExp(r'(Bearer\s+)[A-Za-z0-9._\-]+', caseSensitive: false),
    (Match m) => '${m[1]}***',
  );

  // password= / passphrase= / apiKey= style pairs (URL query or debug dumps).
  text = text.replaceAllMapped(
    RegExp(
      r'((?:password|passphrase|api[_-]?key|agentPassword|privateKey)\s*[=:]\s*)([^\s,&;]+)',
      caseSensitive: false,
    ),
    (Match m) => '${m[1]}***',
  );

  // Inline PEM blocks.
  text = text.replaceAllMapped(
    RegExp(
      r'-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----',
      multiLine: true,
    ),
    (_) => '-----BEGIN … REDACTED-----',
  );

  return text;
}

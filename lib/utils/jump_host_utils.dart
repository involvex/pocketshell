import 'package:ssh_app/models/ssh_profile.dart';

/// Returns true when assigning [jumpProfileId] as the jump host for
/// [profileId] would create a cycle through existing [profiles].
bool createsJumpCycle(
  List<SSHProfile> profiles,
  String profileId,
  String? jumpProfileId,
) {
  if (jumpProfileId == null || jumpProfileId.isEmpty) {
    return false;
  }
  if (jumpProfileId == profileId) {
    return true;
  }

  final byId = <String, SSHProfile>{
    for (final p in profiles) p.id: p,
  };

  var current = jumpProfileId;
  final seen = <String>{profileId};
  while (current.isNotEmpty) {
    if (!seen.add(current)) {
      return true;
    }
    final next = byId[current]?.jumpProfileId;
    if (next == null || next.isEmpty) {
      return false;
    }
    current = next;
  }
  return false;
}

/// Resolves a ProxyJump token (`alias`, `user@host`, `host:port`,
/// `user@host:port`) to an existing profile id, or null when unmatched.
///
/// Prefer matching by profile [SSHProfile.name] (config Host alias), then by
/// host+port (+ optional username).
String? resolveProxyJumpProfileId({
  required List<SSHProfile> profiles,
  required String proxyJump,
}) {
  final token = proxyJump.trim().split(',').first.trim();
  if (token.isEmpty) {
    return null;
  }

  final parsed = parseProxyJumpToken(token);

  for (final p in profiles) {
    if (p.name.toLowerCase() == parsed.aliasOrHost.toLowerCase()) {
      return p.id;
    }
  }

  for (final p in profiles) {
    final hostMatch =
        p.host.toLowerCase() == parsed.aliasOrHost.toLowerCase();
    final portMatch = parsed.port == null || p.port == parsed.port;
    final userMatch = parsed.user == null ||
        p.username.toLowerCase() == parsed.user!.toLowerCase();
    if (hostMatch && portMatch && userMatch) {
      return p.id;
    }
  }
  return null;
}

/// Parsed form of a single ProxyJump hop (comma chains take the first hop).
({String aliasOrHost, String? user, int? port}) parseProxyJumpToken(
  String token,
) {
  var remaining = token.trim();
  String? user;
  final at = remaining.indexOf('@');
  if (at > 0) {
    user = remaining.substring(0, at);
    remaining = remaining.substring(at + 1);
  }

  int? port;
  // IPv6 in brackets: [2001:db8::1]:22
  if (remaining.startsWith('[')) {
    final end = remaining.indexOf(']');
    if (end > 0) {
      final host = remaining.substring(1, end);
      final after = remaining.substring(end + 1);
      if (after.startsWith(':')) {
        port = int.tryParse(after.substring(1));
      }
      return (aliasOrHost: host, user: user, port: port);
    }
  }

  final colon = remaining.lastIndexOf(':');
  if (colon > 0) {
    final maybePort = int.tryParse(remaining.substring(colon + 1));
    if (maybePort != null) {
      port = maybePort;
      remaining = remaining.substring(0, colon);
    }
  }

  return (aliasOrHost: remaining, user: user, port: port);
}

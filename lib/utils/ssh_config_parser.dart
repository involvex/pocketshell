import 'package:ssh_app/models/port_forward_rule.dart';

/// One Host block extracted from an OpenSSH client config.
class SshConfigHostEntry {
  const SshConfigHostEntry({
    required this.alias,
    required this.hostName,
    required this.user,
    required this.port,
    this.identityFile,
    this.proxyJump,
    this.localForwards = const <PortForwardRule>[],
    this.skippedDirectives = const <String>[],
  });

  /// First pattern from the `Host` line (used as profile name).
  final String alias;

  /// `HostName` or [alias] when HostName is omitted.
  final String hostName;

  /// `User` directive, empty when unset.
  final String user;

  /// `Port` directive, defaults to 22.
  final int port;

  /// Optional `IdentityFile` path (hint only — never downloaded).
  final String? identityFile;

  /// First hop from `ProxyJump` when present (unresolved alias/token).
  final String? proxyJump;

  /// Parsed `LocalForward` rules from this host block.
  final List<PortForwardRule> localForwards;

  /// Directives that were present but not applied (ProxyCommand, etc.).
  final List<String> skippedDirectives;
}

/// Result of parsing an OpenSSH config document.
class SshConfigParseResult {
  const SshConfigParseResult({
    required this.hosts,
    this.skippedDirectives = const <String>[],
  });

  final List<SshConfigHostEntry> hosts;

  /// Global / unmatched skipped directive names across the file.
  final List<String> skippedDirectives;
}

/// Parses OpenSSH `~/.ssh/config` text into host entries.
///
/// Supports `Host`, `HostName`, `User`, `Port`, `IdentityFile` (hint),
/// `ProxyJump` (single hop token), and `LocalForward`. `ProxyCommand` and
/// other unsupported directives are collected in
/// [SshConfigHostEntry.skippedDirectives] / [SshConfigParseResult.skippedDirectives].
/// Wildcards (`*`, `?`) in Host patterns are skipped. No secrets are returned.
SshConfigParseResult parseSshConfig(String contents) {
  final hosts = <SshConfigHostEntry>[];
  final globalSkipped = <String>{};

  _HostBuilder? current;
  final pendingSkipped = <String>[];

  void flush() {
    final builder = current;
    if (builder == null) {
      return;
    }
    if (builder.alias.isEmpty || _isWildcardHost(builder.alias)) {
      current = null;
      pendingSkipped.clear();
      return;
    }
    hosts.add(
      SshConfigHostEntry(
        alias: builder.alias,
        hostName: builder.hostName?.isNotEmpty == true
            ? builder.hostName!
            : builder.alias,
        user: builder.user ?? '',
        port: builder.port ?? 22,
        identityFile: builder.identityFile,
        proxyJump: builder.proxyJump,
        localForwards: List<PortForwardRule>.from(builder.localForwards),
        skippedDirectives: List<String>.from(builder.skipped),
      ),
    );
    current = null;
    pendingSkipped.clear();
  }

  for (final rawLine in contents.split('\n')) {
    final line = _stripComment(rawLine).trim();
    if (line.isEmpty) {
      continue;
    }

    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      continue;
    }
    final key = parts.first.toLowerCase();
    final value = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';

    if (key == 'host') {
      flush();
      final alias = value.split(RegExp(r'\s+')).firstWhere(
            (p) => p.isNotEmpty,
            orElse: () => '',
          );
      if (alias.isEmpty || _isWildcardHost(alias)) {
        current = null;
        for (final token in value.split(RegExp(r'\s+'))) {
          if (token.isNotEmpty) {
            globalSkipped.add('Host $token');
          }
        }
        continue;
      }
      current = _HostBuilder(alias: alias);
      current!.skipped.addAll(pendingSkipped);
      pendingSkipped.clear();
      continue;
    }

    final builder = current;
    if (builder == null) {
      if (_isKnownSkipDirective(key)) {
        globalSkipped.add(_canonicalDirective(key));
      }
      continue;
    }

    switch (key) {
      case 'hostname':
        builder.hostName = value;
        break;
      case 'user':
        builder.user = value;
        break;
      case 'port':
        builder.port = int.tryParse(value) ?? builder.port;
        break;
      case 'identityfile':
        builder.identityFile = value;
        break;
      case 'proxyjump':
        // Take the first hop only; multi-hop chains stay partially unsupported.
        final firstHop = value.split(',').first.trim();
        if (firstHop.isNotEmpty) {
          builder.proxyJump = firstHop;
        }
        break;
      case 'localforward':
        final rule = PortForwardRule.tryParseLocalForward(value);
        if (rule != null) {
          builder.localForwards.add(rule);
        } else {
          builder.skipped.add('LocalForward');
        }
        break;
      default:
        if (_isKnownSkipDirective(key) || key.isNotEmpty) {
          builder.skipped.add(_canonicalDirective(key));
        }
    }
  }
  flush();

  return SshConfigParseResult(
    hosts: hosts,
    skippedDirectives: globalSkipped.toList()..sort(),
  );
}

bool _isWildcardHost(String alias) =>
    alias.contains('*') || alias.contains('?') || alias.contains('!');

bool _isKnownSkipDirective(String key) {
  const skipped = <String>{
    'proxycommand',
    'match',
    'include',
    'remoteforward',
    'dynamicforward',
    'canonicaldomains',
    'canonicalizehostname',
  };
  return skipped.contains(key);
}

String _canonicalDirective(String key) {
  switch (key) {
    case 'proxyjump':
      return 'ProxyJump';
    case 'proxycommand':
      return 'ProxyCommand';
    case 'localforward':
      return 'LocalForward';
    case 'remoteforward':
      return 'RemoteForward';
    case 'dynamicforward':
      return 'DynamicForward';
    default:
      if (key.isEmpty) {
        return key;
      }
      return key[0].toUpperCase() + key.substring(1);
  }
}

String _stripComment(String line) {
  final hash = line.indexOf('#');
  if (hash < 0) {
    return line;
  }
  return line.substring(0, hash);
}

class _HostBuilder {
  _HostBuilder({required this.alias});

  final String alias;
  String? hostName;
  String? user;
  int? port;
  String? identityFile;
  String? proxyJump;
  final List<PortForwardRule> localForwards = <PortForwardRule>[];
  final List<String> skipped = <String>[];
}

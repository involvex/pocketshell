import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives Android `ACTION_SEND` text shares via a MethodChannel.
class ShareIntentService {
  ShareIntentService._();

  static const MethodChannel _channel =
      MethodChannel('com.involvex.ssh_app/share_intent');

  static final StreamController<String> _incoming =
      StreamController<String>.broadcast();

  static bool _listening = false;

  /// Shared text events while the app is already running.
  static Stream<String> get incoming => _incoming.stream;

  /// Starts listening for warm-start share events. Safe to call repeatedly.
  static void ensureListening() {
    if (_listening || kIsWeb || !Platform.isAndroid) {
      return;
    }
    _listening = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSharedText') {
        final Object? args = call.arguments;
        if (args is String && args.trim().isNotEmpty) {
          _incoming.add(args);
        }
      }
      return null;
    });
  }

  /// Reads the share text that launched the app (cold start), then clears it.
  static Future<String?> getInitialSharedText() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    ensureListening();
    try {
      final Object? result = await _channel.invokeMethod<Object?>('getSharedText');
      if (result is! String || result.trim().isEmpty) {
        return null;
      }
      await clearSharedText();
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> clearSharedText() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearSharedText');
    } on PlatformException {
      // Ignore — share may already be cleared.
    } on MissingPluginException {
      // Ignore on non-Android builds.
    }
  }

  /// Extracts the first cloneable URL from shared text.
  ///
  /// Prefers GitHub HTTPS / SSH URLs, then any `http(s)` URL, then bare
  /// `github.com/...` paths, then `git@host:path` forms.
  static String? parseGitUrl(String sharedText) {
    final String text = sharedText.trim();
    if (text.isEmpty) {
      return null;
    }

    final RegExp httpsGitHub = RegExp(
      r'https?://(?:www\.)?github\.com/[^\s]+',
      caseSensitive: false,
    );
    final Match? githubMatch = httpsGitHub.firstMatch(text);
    if (githubMatch != null) {
      return _normalizeCloneUrl(githubMatch.group(0)!);
    }

    final RegExp gitSsh = RegExp(
      r'git@[^\s:]+:[^\s]+',
      caseSensitive: false,
    );
    final Match? sshMatch = gitSsh.firstMatch(text);
    if (sshMatch != null) {
      return _normalizeCloneUrl(sshMatch.group(0)!);
    }

    final RegExp anyHttp = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    final Match? httpMatch = anyHttp.firstMatch(text);
    if (httpMatch != null) {
      return _normalizeCloneUrl(httpMatch.group(0)!);
    }

    final RegExp bareGithub = RegExp(
      r'(?:www\.)?github\.com/[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+',
      caseSensitive: false,
    );
    final Match? bareMatch = bareGithub.firstMatch(text);
    if (bareMatch != null) {
      return _normalizeCloneUrl('https://${bareMatch.group(0)!}');
    }

    // Entire payload is already a single token URL-like string.
    if (!text.contains(RegExp(r'\s')) &&
        (text.contains('://') || text.startsWith('git@'))) {
      return _normalizeCloneUrl(text);
    }

    return null;
  }

  /// Builds a paste-ready clone command (no trailing newline / Enter).
  static String buildGitCloneCommand(String url) => 'git clone $url';

  static String _normalizeCloneUrl(String raw) {
    var url = raw.trim();
    // Strip common trailing punctuation from shares / markdown.
    while (url.isNotEmpty &&
        (url.endsWith('.') ||
            url.endsWith(',') ||
            url.endsWith(')') ||
            url.endsWith(']') ||
            url.endsWith('>') ||
            url.endsWith('"'))) {
      url = url.substring(0, url.length - 1);
    }
    // GitHub often shares `.git` already; leave as-is. Strip `/tree/...` etc.
    final RegExp treePath = RegExp(
      r'^(https?://(?:www\.)?github\.com/[^/]+/[^/]+)(?:/(?:tree|blob|pull|issues|actions|commits|releases).*)?$',
      caseSensitive: false,
    );
    final Match? treeMatch = treePath.firstMatch(url);
    if (treeMatch != null) {
      url = treeMatch.group(1)!;
    }
    if (url.endsWith('.git')) {
      return url;
    }
    // Append .git for github https clone URLs without it.
    if (RegExp(r'^https?://(?:www\.)?github\.com/[^/]+/[^/]+/?$',
            caseSensitive: false)
        .hasMatch(url)) {
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      return '$url.git';
    }
    return url;
  }
}

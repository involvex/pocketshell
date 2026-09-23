import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/known_host.dart';

/// First-trust dialog for unknown SSH host keys.
///
/// Returns true when the user explicitly trusts the key.
Future<bool> showUnknownHostKeyDialog(
  BuildContext context,
  KnownHostPrompt prompt,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Unknown host key'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'First connection to ${prompt.host}:${prompt.port}. '
                'Verify this fingerprint out-of-band before trusting it.',
              ),
              const SizedBox(height: 12),
              Text('Key type: ${prompt.keyType}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Fingerprint:'),
              SelectableText(
                prompt.fingerprint,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // ignore: unawaited_futures
              Clipboard.setData(ClipboardData(text: prompt.fingerprint));
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Trust'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shows a hard-block warning for changed host keys. Always returns false
/// (never auto-trusts); re-trust happens explicitly via Settings/host list.
Future<void> showHostKeyChangedWarning(
  BuildContext context, {
  required String host,
  required int port,
  required String expectedFingerprint,
  required String presentedFingerprint,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Host key changed — connection blocked'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'The host key for $host:$port does not match the trusted value. '
                'This can indicate a man-in-the-middle attack. '
                'The connection was blocked.',
              ),
              const SizedBox(height: 12),
              const Text('Trusted:'),
              SelectableText(
                expectedFingerprint,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text('Presented:'),
              SelectableText(
                presentedFingerprint,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Understood'),
          ),
        ],
      );
    },
  );
}

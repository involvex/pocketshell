import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ssh_app/constants/app_metadata.dart';

/// Offline privacy policy from bundled [PRIVACY.md].
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(kPrivacyAssetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load privacy policy'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_privacyPlainText(snapshot.data!)),
          );
        },
      ),
    );
  }
}

String _privacyPlainText(String markdown) {
  return markdown
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('`', '');
}

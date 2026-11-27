import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ssh_app/constants/app_metadata.dart';
import 'package:ssh_app/constants/cloud_ai.dart';
import 'package:ssh_app/screens/privacy_screen.dart';

/// Settings About section: app name, licenses, privacy, source.
class AppAboutTile extends StatefulWidget {
  const AppAboutTile({super.key});

  @override
  State<AppAboutTile> createState() => _AppAboutTileState();
}

class _AppAboutTileState extends State<AppAboutTile> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder:
                (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
              final String versionLabel = snapshot.hasData
                  ? 'Version ${snapshot.data!.version}'
                  : 'Version …';

              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(kAppDisplayName),
                subtitle: Text(versionLabel),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy'),
            subtitle: const Text(
              kCloudAiEnabled
                  ? 'No analytics. Optional AI uses your API key only when you tap the wand.'
                  : 'No analytics. Cloud AI wand disabled in this build.',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () async {
              final info = await _packageInfoFuture;
              if (!context.mounted) {
                return;
              }
              showLicensePage(
                context: context,
                applicationName: kAppDisplayName,
                applicationVersion: info.version,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            subtitle: const Text(kGitHubRepoUrl),
            onTap: () async {
              final uri = Uri.parse(kGitHubRepoUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open GitHub repository'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ssh_app/constants/app_metadata.dart';

/// Settings About section: app name and semver from [PackageInfo].
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
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Built with Flutter'),
            subtitle: Text('Dartssh2, xterm, Provider'),
          ),
        ],
      ),
    );
  }
}

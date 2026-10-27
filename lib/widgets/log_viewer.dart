import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../utils/terminal_style_builder.dart';

class LogViewer extends StatelessWidget {
  const LogViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SSHProvider, SettingsProvider>(
      builder: (context, ssh, settings, child) {
        final textStyle = TerminalStyleBuilder.buildTextStyle(settings);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Connection Logs',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => ssh.connectionLog.clear(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: ssh.connectionLog.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      ssh.connectionLog.reversed.toList()[index],
                      style: textStyle,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

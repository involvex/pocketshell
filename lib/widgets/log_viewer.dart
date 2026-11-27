import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../utils/terminal_style_builder.dart';

class LogViewer extends StatelessWidget {
  const LogViewer({super.key});

  @override
  Widget build(BuildContext context) {
    final ssh = context.read<SSHProvider>();
    final settings = context.watch<SettingsProvider>();
    final textStyle = TerminalStyleBuilder.buildTextStyle(settings);

    return ListenableBuilder(
      listenable: ssh.connectionLogNotifier,
      builder: (context, _) {
        final lines = ssh.connectionLog;
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
                    tooltip: 'Clear logs',
                    onPressed: ssh.clearConnectionLog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      lines[lines.length - 1 - index],
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

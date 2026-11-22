import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/models/port_forward_rule.dart';
import 'package:ssh_app/providers/ssh_provider.dart';

/// Lists active and profile-defined local forwards for the active session.
class PortForwardsSheet extends StatelessWidget {
  const PortForwardsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, ssh, _) {
        final session = ssh.activeSession;
        if (session == null || !session.isConnected) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Connect to a session to manage port forwards'),
          );
        }

        final rules = session.profile.localForwards;
        final activeByRuleId = <String, int>{
          for (final a in session.activeForwards) a.rule.id: a.forward.localPort,
        };

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Local port forwards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (rules.isEmpty)
                  const Text('No forwards configured on this profile.')
                else
                  ...rules.map((rule) {
                    final listening = activeByRuleId.containsKey(rule.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        rule.label.isNotEmpty
                            ? rule.label
                            : 'Port ${rule.localPort}',
                      ),
                      subtitle: Text(
                        '127.0.0.1:${rule.localPort} → '
                        '${rule.remoteHost}:${rule.remotePort}'
                        '${listening ? ' • listening' : ''}',
                      ),
                      trailing: listening
                          ? TextButton(
                              onPressed: () async {
                                await ssh.stopPortForward(
                                  session.id,
                                  ruleId: rule.id,
                                );
                              },
                              child: const Text('Stop'),
                            )
                          : TextButton(
                              onPressed: () async {
                                try {
                                  await ssh.startPortForward(session.id, rule);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Start'),
                            ),
                    );
                  }),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await ssh.startPortForward(
                        session.id,
                        PortForwardRule.rdpPreset,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.desktop_windows),
                  label: const Text('Start RDP forward (3389)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

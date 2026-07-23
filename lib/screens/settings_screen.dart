import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ssh_app/constants/app_metadata.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../widgets/app_about_tile.dart';
import '../widgets/toolbar_action_settings.dart';
import '../widgets/theme_picker.dart';
import '../widgets/shortcut_editor.dart';
import '../widgets/keyboard_shortcut_bar.dart';
import '../widgets/terminal_font_settings.dart';
import '../widgets/terminal_input_settings.dart';
import '../widgets/ai_provider_settings.dart';
import '../widgets/opencode_config_sheet.dart';
import '../providers/agent_provider.dart';
import '../providers/ssh_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  late final TextEditingController _agentPortController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _agentPortController = TextEditingController(
      text: settings.defaultAgentPort.toString(),
    );
  }

  @override
  void dispose() {
    _agentPortController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      await BackupService.export();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final message = await BackupService.import();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // Reload settings provider so theme/shortcuts update immediately
        await Provider.of<SettingsProvider>(context, listen: false)
            .loadSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Appearance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const ThemePicker(),
              const Divider(height: 32),
              const Text('Features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Mobile shortcut bar'),
                      subtitle: const Text(
                        'Show the configured keyboard shortcut bar on Android/iOS',
                      ),
                      value: settings.showMobileShortcutBar,
                      onChanged: settings.setShowMobileShortcutBar,
                    ),
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      title: const Text('Default Agent Port'),
                      subtitle: Text('${settings.defaultAgentPort}'),
                      trailing: SizedBox(
                        width: 120,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          controller: _agentPortController,
                          onSubmitted: (value) {
                            final port = int.tryParse(value);
                            if (port != null && port > 0 && port <= 65535) {
                              settings.setDefaultAgentPort(port);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const ToolbarActionSettings(),
              const Divider(height: 32),
              const Text('Terminal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const TerminalFontSettings(),
              const SizedBox(height: 16),
              const TerminalInputSettings(),
              const Divider(height: 32),
              const Text('AI Provider',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const AiProviderSettings(),
              const Divider(height: 32),
              const Text('OpenCode config',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Consumer2<AgentProvider, SSHProvider>(
                builder: (context, agents, ssh, child) {
                  final hasAgent = agents.connections.isNotEmpty;
                  final hasSsh =
                      ssh.sessions.any((session) => session.isConnected);
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_sync),
                          title: const Text('Import from connected server'),
                          subtitle: const Text(
                            'Load config from the active OpenCode agent',
                          ),
                          enabled: hasAgent,
                          onTap: hasAgent
                              ? () => showOpenCodeConfigFromSettings(context)
                              : null,
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.terminal),
                          title: const Text('Import from SSH host'),
                          subtitle: const Text(
                            'Read ~/.config/opencode from Windows host',
                          ),
                          enabled: hasSsh,
                          onTap: hasSsh
                              ? () => importOpenCodeConfigViaSsh(context)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 32),
              const Text('Keyboard Shortcuts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Card(
                child: ExpansionTile(
                  leading: Icon(Icons.keyboard),
                  title: Text('Configure Shortcuts'),
                  subtitle: Text('Customize keyboard shortcuts'),
                  childrenPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    KeyboardShortcutBar(showRow: 1, forceShowOnMobile: true),
                    SizedBox(height: 8),
                    ShortcutEditor(),
                  ],
                ),
              ),
              const Divider(height: 32),
              const Text('Backup & Restore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_outlined),
                      title: const Text('Export Backup'),
                      subtitle: const Text(
                          'Save profiles, SSH keys, snippets & settings to a file'),
                      trailing: _isExporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _isExporting ? null : _handleExport,
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Import Backup'),
                      subtitle: const Text(
                          'Restore from a previously exported backup file'),
                      trailing: _isImporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _isImporting ? null : _handleImport,
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              const Text('About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const AppAboutTile(),
              const SizedBox(height: 24),
              const _SettingsFooter(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  Future<void> _openGitHubRepo(BuildContext context) async {
    final Uri uri = Uri.parse(kGitHubRepoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub repository')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: TextButton.icon(
        onPressed: () => _openGitHubRepo(context),
        icon:
            Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
        label: Text(
          kGitHubRepoUrl,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

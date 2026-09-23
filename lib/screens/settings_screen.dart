import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ssh_app/constants/app_metadata.dart';
import '../providers/settings_provider.dart';
import '../services/backup_crypto.dart';
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

  Future<String?> _promptBackupPassword({
    required String title,
    String confirmLabel = 'Continue',
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Minimum 8 characters recommended',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirmPlainSecretsExport() async {
    var acknowledged = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Plain backup includes secrets?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'A plain backup with secrets stores private keys and passwords as readable JSON. '
                    'Anyone with the file can use them. Encrypted export is recommended.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I understand the risk'),
                    value: acknowledged,
                    onChanged: (value) => setDialogState(
                      () => acknowledged = value ?? false,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      acknowledged ? () => Navigator.pop(dialogContext) : null,
                  child: const Text('Export with secrets'),
                ),
              ],
            );
          },
        );
      },
    );
    return acknowledged;
  }

  Future<void> _handleExport() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Export backup'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'encrypted'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text('Encrypted (recommended)'),
                subtitle:
                    Text('Password-protected, includes keys and passwords'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'plain'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined),
                title: Text('Plain JSON (no secrets)'),
                subtitle: Text('Safe to store anywhere, secrets stripped'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'plain-secrets'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Plain JSON with secrets'),
                subtitle: Text('Not recommended'),
              ),
            ),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;
    setState(() => _isExporting = true);
    try {
      switch (choice) {
        case 'encrypted':
          final password = await _promptBackupPassword(
            title: 'Backup password',
            confirmLabel: 'Export',
          );
          if (password == null || password.isEmpty) return;
          if (password.length < 8 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Use at least 8 characters for backup password'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          await BackupService.exportEncrypted(password);
          break;
        case 'plain-secrets':
          final ok = await _confirmPlainSecretsExport();
          if (!ok) return;
          await BackupService.exportPlain(includeSecrets: true);
          break;
        default:
          await BackupService.exportPlain();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported')),
        );
      }
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
      String message;
      try {
        message = await BackupService.import();
      } on BackupCryptoException {
        if (!mounted) return;
        final password = await _promptBackupPassword(
          title: 'Encrypted backup password',
          confirmLabel: 'Import',
        );
        if (password == null || password.isEmpty) return;
        message = await BackupService.import(password: password);
      }
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
              const Text('Security',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Require passphrase for keys'),
                      subtitle: const Text(
                        'Block key auth when the SSH key has no passphrase',
                      ),
                      value: settings.requireKeyPassphrase,
                      onChanged: settings.setRequireKeyPassphrase,
                    ),
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      title: const Text('Idle auto-disconnect'),
                      subtitle: const Text(
                        'Disconnect SSH sessions after inactivity',
                      ),
                      trailing: DropdownButton<int>(
                        value: settings.sessionIdleTimeoutMinutes,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Off')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setSessionIdleTimeoutMinutes(value);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16),
                    Consumer<SSHProvider>(
                      builder: (context, ssh, child) {
                        return FutureBuilder(
                          future: ssh.getKnownHosts(),
                          builder: (context, snapshot) {
                            final hosts = snapshot.data ?? [];
                            if (hosts.isEmpty) {
                              return const ListTile(
                                leading: Icon(Icons.verified_user_outlined),
                                title: Text('Trusted host keys'),
                                subtitle: Text(
                                  'No hosts trusted yet — fingerprints appear here after first connection',
                                ),
                              );
                            }
                            return ExpansionTile(
                              leading: const Icon(Icons.verified_user_outlined),
                              title:
                                  Text('Trusted host keys (${hosts.length})'),
                              subtitle: const Text(
                                  'Remove a host to require re-trust on next connect'),
                              children: [
                                for (final h in hosts)
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                        '${h.host}:${h.port} • ${h.keyType}'),
                                    subtitle: Text(
                                      h.fingerprint,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      tooltip: 'Forget (re-trust next time)',
                                      onPressed: () async {
                                        await ssh.forgetKnownHost(
                                            h.host, h.port);
                                        if (context.mounted) {
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart' hide ConfigService, Provider;
import 'package:provider/provider.dart';

import '../models/agent_connection.dart';
import '../models/ssh_profile.dart';
import '../providers/agent_provider.dart';
import '../providers/ssh_provider.dart';
import '../services/config_service.dart';
import '../services/opencode_remote_config_service.dart';

Future<void> showOpenCodeConfigSheet(
  BuildContext context,
  AgentConnection connection,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _OpenCodeConfigSheet(connection: connection),
  );
}

class _OpenCodeConfigSheet extends StatefulWidget {
  const _OpenCodeConfigSheet({required this.connection});

  final AgentConnection connection;

  @override
  State<_OpenCodeConfigSheet> createState() => _OpenCodeConfigSheetState();
}

class _OpenCodeConfigSheetState extends State<_OpenCodeConfigSheet> {
  bool _loading = true;
  String? _error;
  ConfigResponse? _config;
  ConfigProvidersResponse? _providers;
  Map<String, dynamic>? _cached;
  final TextEditingController _patchController = TextEditingController(
    text: '{}',
  );

  @override
  void initState() {
    super.initState();
    // ignore: unawaited_futures
    _load();
  }

  @override
  void dispose() {
    _patchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _cached = await ConfigService.getOpenCodeServerConfigCache();
      final results = await Future.wait<Object>(<Future<Object>>[
        widget.connection.service.getConfig(),
        widget.connection.service.getConfigProviders(),
      ]);
      _config = results[0] as ConfigResponse;
      _providers = results[1] as ConfigProvidersResponse;
      await ConfigService.saveOpenCodeServerConfigCache(
        <String, dynamic>{
          'providers': _config?.providers,
          'defaultModels': _config?.defaultModels,
        },
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _applyPatch() async {
    try {
      final body = json.decode(_patchController.text) as Map<String, dynamic>;
      final updated = await widget.connection.service.updateConfig(body);
      setState(() => _config = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config updated on server')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFromSsh() async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final session =
        ssh.findConnectedSessionForHost(widget.connection.profile.host);
    if (session?.client == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect SSH to the agent host first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    const service = OpenCodeRemoteConfigService();
    final remote = await service.importFromSshClient(
      client: session!.client!,
      profile: widget.connection.profile,
    );

    if (!mounted) return;
    if (remote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No OpenCode config found on remote host'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply to profile?'),
        content: Text(
          'Found ${remote.sourcePath}\n'
          'Port: ${remote.agentPort ?? 'unchanged'}\n'
          'Directory: ${remote.directory ?? 'none'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (apply != true || !mounted) return;

    final profile = widget.connection.profile;
    final updated = profile.copyWith(
      agentPort: remote.agentPort ?? profile.agentPort,
      password: remote.password ?? profile.password,
    );
    await Provider.of<SSHProvider>(context, listen: false).saveProfile(updated);

    if (!mounted) return;
    if (remote.directory != null && remote.directory!.isNotEmpty) {
      await Provider.of<AgentProvider>(context, listen: false)
          .setDirectory(widget.connection.id, remote.directory!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated from remote config')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'OpenCode server config',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.connection.profile.agentBaseUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
                TextButton.icon(
                  onPressed: _importFromSsh,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Import via SSH'),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _config == null
                      ? Center(child: Text(_error!))
                      : ListView(
                          children: [
                            if (_cached != null && _config == null)
                              Text(
                                'Showing cached config (offline)',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            _Section(
                              title: 'Providers',
                              body: _prettyJson(
                                _config?.providers ??
                                    _cached?['providers']
                                        as Map<String, dynamic>?,
                              ),
                            ),
                            _Section(
                              title: 'Default models',
                              body: _prettyJson(
                                _config?.defaultModels ??
                                    _cached?['defaultModels']
                                        as Map<String, dynamic>?,
                              ),
                            ),
                            if (_providers != null)
                              _Section(
                                title: 'Config providers API',
                                body: _prettyJson(_providers!.toJson()),
                              ),
                            const SizedBox(height: 12),
                            const Text('PATCH body (JSON)'),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _patchController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '{"key": "value"}',
                              ),
                              minLines: 3,
                              maxLines: 6,
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _applyPatch,
                              child: const Text('Update on server'),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyJson(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) return '(empty)';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }
}

Future<void> showOpenCodeConfigFromSettings(BuildContext context) async {
  final agents = Provider.of<AgentProvider>(context, listen: false);
  final connection = agents.activeConnection;
  if (connection == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect to an agent first'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  await showOpenCodeConfigSheet(context, connection);
}

Future<void> importOpenCodeConfigViaSsh(BuildContext context) async {
  final ssh = Provider.of<SSHProvider>(context, listen: false);

  final connected = ssh.sessions.where((s) => s.isConnected).toList();
  if (connected.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No connected SSH sessions'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  SSHProfile? profile;
  if (connected.length == 1) {
    profile = connected.first.profile;
  } else {
    profile = await showDialog<SSHProfile>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Pick SSH session'),
        children: connected
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, s.profile),
                child: Text('${s.name} (${s.profile.host})'),
              ),
            )
            .toList(),
      ),
    );
  }

  if (profile == null || !context.mounted) return;

  final session = ssh.findConnectedSessionForHost(profile.host);
  if (session?.client == null) return;

  final remote = await const OpenCodeRemoteConfigService().importFromSshClient(
    client: session!.client!,
    profile: profile,
  );

  if (!context.mounted) return;
  if (remote == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No OpenCode config found on host'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final updated = profile.copyWith(
    agentPort: remote.agentPort ?? profile.agentPort,
    password: remote.password ?? profile.password,
  );
  await ssh.saveProfile(updated);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Imported from ${remote.sourcePath}')),
  );
}

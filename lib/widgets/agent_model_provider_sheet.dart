import 'package:flutter/material.dart';
import 'package:opencode_api/opencode_api.dart' as opencode_api;
import 'package:provider/provider.dart';

import '../models/agent_connection.dart';
import '../models/agent_model_option.dart';
import '../providers/agent_provider.dart';
import '../utils/agent_prompt_utils.dart';

class AgentModelProviderSheet extends StatefulWidget {
  const AgentModelProviderSheet({
    required this.connection,
    super.key,
  });

  final AgentConnection connection;

  @override
  State<AgentModelProviderSheet> createState() =>
      _AgentModelProviderSheetState();
}

class _AgentModelProviderSheetState extends State<AgentModelProviderSheet> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _selectedProviderId;
  bool _isConnecting = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Provider.of<AgentProvider>(context, listen: false)
        .refreshProviders(widget.connection.id);
  }

  Future<void> _connectProvider() async {
    final providerId = _selectedProviderId;
    final apiKey = _apiKeyController.text.trim();
    if (providerId == null || providerId.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a provider and enter an API key')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    try {
      await Provider.of<AgentProvider>(context, listen: false).connectProvider(
        widget.connection.id,
        providerId,
        apiKey,
      );
      if (!mounted) return;
      _apiKeyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected provider: $providerId')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _selectModel(String modelId) async {
    final agents = Provider.of<AgentProvider>(context, listen: false);
    await agents.setModel(widget.connection.id, modelId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _browseAllModels() async {
    final agents = Provider.of<AgentProvider>(context, listen: false);
    await agents.openModelsPicker(widget.connection.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Map<String, List<AgentModelOption>> _groupedModels(
    List<AgentModelOption> options,
  ) {
    final grouped = <String, List<AgentModelOption>>{};
    for (final option in options) {
      grouped.putIfAbsent(option.providerId, () => <AgentModelOption>[]);
      grouped[option.providerId]!.add(option);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentProvider>(
      builder: (context, agents, child) {
        final connection = agents.connections.firstWhere(
          (AgentConnection c) => c.id == widget.connection.id,
          orElse: () => widget.connection,
        );
        final providers =
            connection.providerInfo?.all ?? <opencode_api.Provider>[];
        final currentModel = agents.currentModelId(connection);
        final groupedModels = _groupedModels(connection.modelOptions);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Material(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Model & Providers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: connection.isLoadingMetadata ? null : _refresh,
                          icon: connection.isLoadingMetadata
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  if (currentModel != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Current model: $currentModel',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Text(
                          'Providers',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (providers.isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text('No providers available'),
                          )
                        else
                          ...providers.map((opencode_api.Provider provider) {
                            final providerId = provider.id ?? '';
                            final connected = isProviderConnected(
                              provider,
                              connection.providerInfo,
                            );
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.circle,
                                size: 10,
                                color: connected ? Colors.green : Colors.grey,
                              ),
                              title: Text(provider.name ?? providerId),
                              subtitle: provider.description == null
                                  ? null
                                  : Text(provider.description!),
                            );
                          }),
                        const Divider(height: 24),
                        Text(
                          'Connect provider',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        DropdownMenu<String>(
                          label: const Text('Provider'),
                          dropdownMenuEntries: providers
                              .map(
                                (opencode_api.Provider provider) =>
                                    DropdownMenuEntry<String>(
                                  value: provider.id ?? '',
                                  label: provider.name ?? provider.id ?? '',
                                ),
                              )
                              .where(
                                (DropdownMenuEntry<String> entry) =>
                                    entry.value.isNotEmpty,
                              )
                              .toList(),
                          onSelected: (String? value) {
                            setState(() => _selectedProviderId = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiKeyController,
                          decoration: const InputDecoration(
                            labelText: 'API key',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _isConnecting ? null : _connectProvider,
                          child: _isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save & connect'),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Models',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton(
                              onPressed: connection.activeSessionId == null
                                  ? null
                                  : _browseAllModels,
                              child: const Text('Browse all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (groupedModels.isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text('No models listed'),
                            subtitle: Text(
                              'Use Browse all or /models in the prompt',
                            ),
                          )
                        else
                          ...groupedModels.entries.expand(
                            (MapEntry<String, List<AgentModelOption>> entry) {
                              return <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                                  child: Text(
                                    entry.key,
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                                ...entry.value.map((AgentModelOption option) {
                                  final selected =
                                      currentModel == option.commandValue;
                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    title: Text(
                                      option.modelId,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(option.commandValue),
                                    trailing: selected
                                        ? const Icon(Icons.check, size: 18)
                                        : null,
                                    onTap: connection.activeSessionId == null
                                        ? null
                                        : () => _selectModel(option.commandValue),
                                  );
                                }),
                              ];
                            },
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

void showAgentModelProviderSheet(
  BuildContext context,
  AgentConnection connection,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AgentModelProviderSheet(connection: connection),
  );
}

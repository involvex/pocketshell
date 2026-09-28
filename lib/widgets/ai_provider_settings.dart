import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_gateway_service.dart';

class AiProviderSettings extends StatefulWidget {
  const AiProviderSettings({super.key});

  @override
  State<AiProviderSettings> createState() => _AiProviderSettingsState();
}

class _AiProviderSettingsState extends State<AiProviderSettings> {
  late final TextEditingController _opencodeKeyController;
  late final TextEditingController _kiloKeyController;
  List<String> _models = [];
  bool _isLoadingModels = false;
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _opencodeKeyController =
        TextEditingController(text: settings.opencodeZenApiKey);
    _kiloKeyController = TextEditingController(text: settings.kiloApiKey);
  }

  @override
  void dispose() {
    _opencodeKeyController.dispose();
    _kiloKeyController.dispose();
    super.dispose();
  }

  Future<void> _refreshModels(SettingsProvider settings) async {
    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });

    try {
      final models = await AiGatewayService.fetchModels(
        provider: settings.aiProvider,
        apiKey: settings.activeAiApiKey,
      );
      if (!mounted) return;
      setState(() {
        _models = models;
        _isLoadingModels = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _models = _fallbackModels(settings.aiProvider);
        _modelsError = e.toString();
        _isLoadingModels = false;
      });
    }
  }

  List<String> _fallbackModels(AiProvider provider) {
    return switch (provider) {
      AiProvider.opencodeZen => [AiProviderDefaults.opencodeZenModel],
      AiProvider.kiloGateway => [AiProviderDefaults.kiloModel],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final activeModel = settings.activeAiModel;
        final modelOptions =
            _models.isEmpty ? _fallbackModels(settings.aiProvider) : _models;
        final selectedModel = modelOptions.contains(activeModel)
            ? activeModel
            : modelOptions.first;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Provider'),
                const SizedBox(height: 8),
                SegmentedButton<AiProvider>(
                  segments: const [
                    ButtonSegment(
                      value: AiProvider.opencodeZen,
                      label: Text('OpenCode Zen'),
                    ),
                    ButtonSegment(
                      value: AiProvider.kiloGateway,
                      label: Text('Kilo Gateway'),
                    ),
                  ],
                  selected: {settings.aiProvider},
                  onSelectionChanged: (selection) {
                    settings.setAiProvider(selection.first);
                    setState(() {
                      _models = [];
                      _modelsError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'API keys are stored securely on this device and are not '
                  'included in backups.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (settings.aiProvider == AiProvider.opencodeZen) ...[
                  TextField(
                    controller: _opencodeKeyController,
                    decoration: const InputDecoration(
                      labelText: 'OpenCode Zen API Key',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: settings.setOpencodeZenApiKey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default model: ${AiProviderDefaults.opencodeZenModel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  TextField(
                    controller: _kiloKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Kilo API Key',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: settings.setKiloApiKey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default model: ${AiProviderDefaults.kiloModel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${settings.aiProvider.name}-$selectedModel',
                        ),
                        initialValue: selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                        items: modelOptions
                            .map(
                              (model) => DropdownMenuItem<String>(
                                value: model,
                                child: Text(model),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          if (settings.aiProvider == AiProvider.opencodeZen) {
                            settings.setOpencodeZenModel(value);
                          } else {
                            settings.setKiloModel(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh models',
                      onPressed: _isLoadingModels
                          ? null
                          : () => _refreshModels(settings),
                      icon: _isLoadingModels
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_modelsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _modelsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

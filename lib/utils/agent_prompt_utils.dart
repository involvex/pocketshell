import 'package:opencode_api/opencode_api.dart';

import '../models/agent_model_option.dart';

bool isSlashCommand(String input) => input.trimLeft().startsWith('/');

String? slashCommandPrefix(String input) {
  final trimmed = input.trimLeft();
  if (!trimmed.startsWith('/')) return null;
  final body = trimmed.substring(1);
  final spaceIndex = body.indexOf(' ');
  if (spaceIndex == -1) return body;
  return body.substring(0, spaceIndex);
}

String? slashCommandArgumentPrefix(String input) {
  final trimmed = input.trimLeft();
  if (!trimmed.startsWith('/')) return null;
  final body = trimmed.substring(1);
  final spaceIndex = body.indexOf(' ');
  if (spaceIndex == -1) return null;
  return body.substring(spaceIndex + 1);
}

bool isAgentCommandInput(String input) {
  return slashCommandPrefix(input) == 'agent';
}

bool isModelCommandInput(String input) {
  return slashCommandPrefix(input) == 'model';
}

bool isConnectCommandInput(String input) {
  final prefix = slashCommandPrefix(input);
  return prefix == 'connect' || prefix == 'models';
}

List<Command> filterCommandsByPrefix(List<Command> commands, String prefix) {
  if (prefix.isEmpty) return commands;
  final lower = prefix.toLowerCase();
  return commands
      .where((Command command) {
        final name = command.name ?? command.id ?? '';
        return name.toLowerCase().startsWith(lower);
      })
      .toList();
}

List<String> agentNameSuggestions(List<Agent> agents, String prefix) {
  final lower = prefix.toLowerCase();
  return agents
      .map((Agent agent) => agent.name ?? agent.id ?? '')
      .where((String name) => name.isNotEmpty)
      .where((String name) => lower.isEmpty || name.toLowerCase().startsWith(lower))
      .toList();
}

List<String> modelIdSuggestions(List<AgentModelOption> models, String prefix) {
  final lower = prefix.toLowerCase();
  return models
      .map((AgentModelOption option) => option.commandValue)
      .where(
        (String id) => lower.isEmpty || id.toLowerCase().contains(lower),
      )
      .toList();
}

List<AgentModelOption> deriveModelOptions({
  ProviderListResponse? providerInfo,
  ConfigProvidersResponse? configProviders,
}) {
  final seen = <String>{};
  final options = <AgentModelOption>[];

  void addEntry(String providerId, String modelId) {
    if (providerId.isEmpty || modelId.isEmpty) return;
    final key = '$providerId::$modelId';
    if (seen.contains(key)) return;
    seen.add(key);
    options.add(AgentModelOption(providerId: providerId, modelId: modelId));
  }

  final providerDefaults = providerInfo?.default_ ?? <String, String>{};
  for (final entry in providerDefaults.entries) {
    addEntry(entry.key, entry.value);
  }

  final configDefaults = configProviders?.default_ ?? <String, String>{};
  for (final entry in configDefaults.entries) {
    addEntry(entry.key, entry.value);
  }

  options.sort(
    (AgentModelOption a, AgentModelOption b) =>
        a.commandValue.compareTo(b.commandValue),
  );
  return options;
}

String? resolveCurrentModelId({
  String? selectedModelId,
  ProviderListResponse? providerInfo,
  ConfigProvidersResponse? configProviders,
}) {
  if (selectedModelId != null && selectedModelId.isNotEmpty) {
    return selectedModelId;
  }

  final defaults = providerInfo?.default_ ?? configProviders?.default_;
  if (defaults == null || defaults.isEmpty) return null;
  return defaults.values.first;
}

bool isProviderConnected(Provider provider, ProviderListResponse? providerInfo) {
  if (provider.connected == true) return true;
  final providerId = provider.id;
  if (providerId == null) return false;
  return providerInfo?.connected?.contains(providerId) ?? false;
}

class PromptSuggestion {
  const PromptSuggestion({
    required this.label,
    required this.insertText,
    this.description,
  });

  final String label;
  final String insertText;
  final String? description;
}

List<PromptSuggestion> buildPromptSuggestions({
  required String input,
  required List<Command> commands,
  required List<Agent> agents,
  required List<AgentModelOption> models,
}) {
  if (!isSlashCommand(input)) return const <PromptSuggestion>[];

  final commandPrefix = slashCommandPrefix(input) ?? '';
  final argumentPrefix = slashCommandArgumentPrefix(input) ?? '';

  if (isAgentCommandInput(input)) {
    return agentNameSuggestions(agents, argumentPrefix)
        .map(
          (String name) => PromptSuggestion(
            label: name,
            insertText: '/agent $name',
            description: 'Switch agent',
          ),
        )
        .toList();
  }

  if (isModelCommandInput(input)) {
    return modelIdSuggestions(models, argumentPrefix)
        .map(
          (String modelId) => PromptSuggestion(
            label: modelId,
            insertText: '/model $modelId',
            description: 'Switch model',
          ),
        )
        .toList();
  }

  return filterCommandsByPrefix(commands, commandPrefix)
      .map(
        (Command command) {
          final name = command.name ?? command.id ?? '';
          return PromptSuggestion(
            label: '/$name',
            insertText: '/$name',
            description: command.description,
          );
        },
      )
      .toList();
}

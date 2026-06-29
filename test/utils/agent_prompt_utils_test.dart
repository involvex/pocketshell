import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_api/opencode_api.dart';

import 'package:ssh_app/models/agent_model_option.dart';
import 'package:ssh_app/utils/agent_prompt_utils.dart';

void main() {
  group('isSlashCommand', () {
    test('returns true for slash-prefixed input', () {
      expect(isSlashCommand('/help'), isTrue);
      expect(isSlashCommand('  /agent build'), isTrue);
    });

    test('returns false for normal prompts', () {
      expect(isSlashCommand('hello'), isFalse);
      expect(isSlashCommand(''), isFalse);
    });
  });

  group('slashCommandPrefix', () {
    test('extracts command name before arguments', () {
      expect(slashCommandPrefix('/agent build'), 'agent');
      expect(slashCommandPrefix('/model anthropic/claude'), 'model');
      expect(slashCommandPrefix('/help'), 'help');
    });
  });

  group('agentNameSuggestions', () {
    test('filters agents by prefix', () {
      final agents = <Agent>[
        Agent(id: '1', name: 'build'),
        Agent(id: '2', name: 'plan'),
      ];

      expect(agentNameSuggestions(agents, 'bu'), <String>['build']);
    });
  });

  group('deriveModelOptions', () {
    test('merges provider and config defaults without duplicates', () {
      final options = deriveModelOptions(
        providerInfo: ProviderListResponse(
          default_: <String, String>{
            'anthropic': 'claude-sonnet',
            'opencode': 'mimo-v2.5-free',
          },
        ),
        configProviders: ConfigProvidersResponse(
          default_: <String, String>{
            'anthropic': 'claude-sonnet',
            'openai': 'gpt-4o',
          },
        ),
      );

      expect(options, hasLength(3));
      expect(
        options.map((AgentModelOption o) => o.commandValue),
        containsAll(<String>[
          'anthropic/claude-sonnet',
          'opencode/mimo-v2.5-free',
          'openai/gpt-4o',
        ]),
      );
    });
  });

  group('buildPromptSuggestions', () {
    test('suggests agents for /agent prefix', () {
      final suggestions = buildPromptSuggestions(
        input: '/agent bu',
        commands: const <Command>[],
        agents: <Agent>[Agent(name: 'build')],
        models: const <AgentModelOption>[],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.first.insertText, '/agent build');
    });

    test('suggests models for /model prefix', () {
      final suggestions = buildPromptSuggestions(
        input: '/model ant',
        commands: const <Command>[],
        agents: const <Agent>[],
        models: const <AgentModelOption>[
          AgentModelOption(providerId: 'anthropic', modelId: 'claude-sonnet'),
        ],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.first.insertText, '/model anthropic/claude-sonnet');
    });

    test('filters commands by prefix', () {
      final suggestions = buildPromptSuggestions(
        input: '/he',
        commands: <Command>[
          Command(name: 'help', description: 'Show help'),
          Command(name: 'agent', description: 'Switch agent'),
        ],
        agents: const <Agent>[],
        models: const <AgentModelOption>[],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.first.label, '/help');
    });
  });

  group('resolveCurrentModelId', () {
    test('prefers selected model over defaults', () {
      expect(
        resolveCurrentModelId(
          selectedModelId: 'anthropic/claude-haiku',
          providerInfo: ProviderListResponse(
            default_: <String, String>{'anthropic': 'claude-sonnet'},
          ),
        ),
        'anthropic/claude-haiku',
      );
    });
  });
}

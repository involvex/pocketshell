import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/agent_prompt_attachment.dart';
import 'package:ssh_app/services/opencode_v2_mappers.dart';

void main() {
  group('unwrapV2Data', () {
    test('returns inner data payload', () {
      expect(
        unwrapV2Data(<String, dynamic>{
          'data': <String, dynamic>{'id': 'ses_1'},
        }),
        <String, dynamic>{'id': 'ses_1'},
      );
    });

    test('returns body when no envelope', () {
      expect(unwrapV2Data(<String, dynamic>{'id': 'x'}), <String, dynamic>{
        'id': 'x',
      });
    });
  });

  group('mapV2Session', () {
    test('maps location.directory and time', () {
      final session = mapV2Session(<String, dynamic>{
        'id': 'ses_1',
        'projectID': 'proj',
        'title': 'Demo',
        'location': <String, dynamic>{'directory': r'I:\dev\app'},
        'time': <String, dynamic>{
          'created': 1000,
          'updated': 2000,
        },
      });

      expect(session.id, 'ses_1');
      expect(session.directory, r'I:\dev\app');
      expect(session.title, 'Demo');
      expect(session.time?.updated, 2000);
    });
  });

  group('mapV2Message', () {
    test('maps user text message', () {
      final message = mapV2Message(<String, dynamic>{
        'id': 'msg_1',
        'type': 'user',
        'text': 'hello',
        'time': <String, dynamic>{'created': 1793063165868},
      });

      expect(message.info?.role, 'user');
      expect(message.parts?.single.text, 'hello');
    });

    test('maps tool part patch from metadata', () {
      final message = mapV2Message(<String, dynamic>{
        'id': 'msg_patch',
        'type': 'assistant',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'tool',
            'id': 'call_patch',
            'name': 'edit',
            'state': <String, dynamic>{
              'status': 'completed',
              'metadata': <String, dynamic>{
                'patch': '--- a/foo\n+++ b/foo\n@@\n-old\n+new',
              },
            },
          },
        ],
      });

      expect(message.parts?.single.text, contains('@@'));
      expect(
        looksLikeUnifiedDiff(message.parts!.single.text!),
        isTrue,
      );
    });

    test('maps assistant content parts', () {
      final message = mapV2Message(<String, dynamic>{
        'id': 'msg_2',
        'type': 'assistant',
        'time': <String, dynamic>{'created': 1793063165868},
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'reasoning', 'text': 'think'},
          <String, dynamic>{'type': 'text', 'text': 'answer'},
          <String, dynamic>{
            'type': 'tool',
            'id': 'call_1',
            'name': 'shell',
            'state': <String, dynamic>{
              'status': 'completed',
              'output': 'ok',
            },
          },
        ],
      });

      expect(message.info?.role, 'assistant');
      expect(message.parts?.length, 3);
      expect(message.parts?[1].type, 'text');
      expect(message.parts?[1].text, 'answer');
      expect(message.parts?[2].type, 'tool');
      expect(message.parts?[2].text, contains('shell'));
    });
  });

  group('parseSlashCommand', () {
    test('splits name and arguments', () {
      final parsed = parseSlashCommand('/model kilo/free');
      expect(parsed.name, 'model');
      expect(parsed.text, 'kilo/free');
    });

    test('handles bare command', () {
      final parsed = parseSlashCommand('/status');
      expect(parsed.name, 'status');
      expect(parsed.text, '');
    });
  });

  group('mapPermissionDecision', () {
    test('maps allow/deny/remember', () {
      expect(mapPermissionDecision('allow', remember: false), 'once');
      expect(mapPermissionDecision('allow', remember: true), 'always');
      expect(mapPermissionDecision('deny', remember: false), 'reject');
    });
  });

  group('normalizeV2Event', () {
    test('copies data into properties', () {
      final event = normalizeV2Event(<String, dynamic>{
        'type': 'session.step.started',
        'data': <String, dynamic>{'sessionID': 'ses_1'},
      });
      expect(event['properties'], <String, dynamic>{'sessionID': 'ses_1'});
    });

    test('aliases permission events', () {
      final event = normalizeV2Event(<String, dynamic>{
        'type': 'session.permission.asked',
        'data': <String, dynamic>{
          'id': 'perm_1',
          'sessionID': 'ses_1',
          'action': 'edit',
        },
      });
      expect(event['type'], 'permission.asked');
      final props = event['properties'] as Map<String, dynamic>;
      expect(props['permissionID'], 'perm_1');
    });
  });

  group('extractV2Usage', () {
    test('reads assistant tokens and cost', () {
      final usage = extractV2Usage(<String, dynamic>{
        'type': 'assistant',
        'tokens': <String, dynamic>{
          'input': 1200,
          'output': 340,
          'reasoning': 0,
          'cache': <String, dynamic>{'read': 0, 'write': 0},
        },
        'cost': 0.0042,
      });

      expect(usage?.inputTokens, 1200);
      expect(usage?.outputTokens, 340);
      expect(usage?.cost, closeTo(0.0042, 0.0001));
    });

    test('sumV2MessageUsage aggregates assistant turns', () {
      final total = sumV2MessageUsage(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'assistant',
          'tokens': <String, dynamic>{
            'input': 100,
            'output': 50,
            'reasoning': 0,
            'cache': <String, dynamic>{'read': 0, 'write': 0},
          },
          'cost': 0.001,
        },
        <String, dynamic>{
          'type': 'assistant',
          'tokens': <String, dynamic>{
            'input': 200,
            'output': 25,
            'reasoning': 0,
            'cache': <String, dynamic>{'read': 0, 'write': 0},
          },
          'cost': 0.002,
        },
      ]);

      expect(total.inputTokens, 300);
      expect(total.outputTokens, 75);
      expect(total.cost, closeTo(0.003, 0.0001));
    });
  });

  group('AgentPromptAttachment', () {
    test('remote path payload uses uri source', () {
      final attachment =
          AgentPromptAttachment.remotePath(r'I:\dev\proj\main.dart');
      expect(attachment.apiPayload['uri'], r'I:\dev\proj\main.dart');
      final source = attachment.apiPayload['source'] as Map<String, dynamic>;
      expect(source['type'], 'uri');
    });
  });

  group('defaultsFromV2ConfigInfo', () {
    test('reads top-level and agent models', () {
      final defaults = defaultsFromV2ConfigInfo(<String, dynamic>{
        'model': <String, dynamic>{
          'providerID': 'kilo',
          'model': 'kilo-auto/free',
        },
        'agents': <String, dynamic>{
          'plan': <String, dynamic>{
            'model': <String, dynamic>{
              'providerID': 'nvidia',
              'model': 'deepseek',
            },
          },
        },
      });

      expect(defaults['kilo'], 'kilo-auto/free');
      expect(defaults['nvidia'], 'deepseek');
    });
  });
}

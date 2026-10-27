import 'package:flutter_test/flutter_test.dart';
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

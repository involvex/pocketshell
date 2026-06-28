import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_api/opencode_api.dart' hide ConfigService;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/models/agent_connection.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/opencode_connection_service.dart';
import 'package:ssh_app/utils/agent_session_utils.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConfigService.init();
  });

  group('sortSessionsByUpdatedDesc', () {
    test('orders sessions by updated timestamp descending', () {
      final sessions = <Session>[
        Session(
          id: 'old',
          time: SessionTime(created: 100, updated: 200),
        ),
        Session(
          id: 'new',
          time: SessionTime(created: 300, updated: 500),
        ),
        Session(
          id: 'mid',
          time: SessionTime(created: 150, updated: 400),
        ),
      ];

      final sorted = sortSessionsByUpdatedDesc(sessions);

      expect(sorted.map((Session s) => s.id).toList(), <String>[
        'new',
        'mid',
        'old',
      ]);
    });

    test('falls back to created when updated is missing', () {
      final sessions = <Session>[
        Session(id: 'a', time: SessionTime(created: 100)),
        Session(id: 'b', time: SessionTime(created: 300)),
      ];

      final sorted = sortSessionsByUpdatedDesc(sessions);

      expect(sorted.first.id, 'b');
    });
  });

  group('formatSessionTimestamp', () {
    test('returns empty string for null', () {
      expect(formatSessionTimestamp(null), '');
    });

    test('formats recent timestamps as relative', () {
      final now = DateTime.now();
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      expect(formatSessionTimestamp(seconds), 'Just now');
    });
  });

  group('agentDirectoryScopeForConnection', () {
    late OpenCodeConnectionService service;
    late SSHProfile profile;

    setUp(() {
      service = OpenCodeConnectionService(
        baseUrl: 'http://127.0.0.1:5000',
        username: 'opencode',
        password: '',
      );
      profile = SSHProfile(
        name: 'Local Desktop',
        host: '127.0.0.1',
        username: 'opencode',
      );
    });

    test('returns selected directory for local connections', () {
      final connection = AgentConnection(
        id: 'c1',
        profile: profile,
        service: service,
        sessions: const <Session>[],
        isConnected: true,
        isLocal: true,
        selectedDirectory: 'D:/repos/myproject',
      );

      expect(
        agentDirectoryScopeForConnection(connection),
        'D:/repos/myproject',
      );
    });

    test('returns selected directory for remote connections', () {
      final connection = AgentConnection(
        id: 'c1',
        profile: profile,
        service: service,
        sessions: const <Session>[],
        isConnected: true,
        selectedDirectory: '/home/user/project',
      );

      expect(
        agentDirectoryScopeForConnection(connection),
        '/home/user/project',
      );
    });

    test('returns null when no directory selected', () {
      final connection = AgentConnection(
        id: 'c1',
        profile: profile,
        service: service,
        sessions: const <Session>[],
        isConnected: true,
        selectedDirectory: 'D:/repos/myproject',
      );

      expect(agentDirectoryScopeForConnection(connection), isNotNull);

      final emptyConnection = AgentConnection(
        id: 'c2',
        profile: profile,
        service: service,
        sessions: const <Session>[],
        isConnected: true,
      );

      expect(agentDirectoryScopeForConnection(emptyConnection), isNull);
    });

    test('local connection has isLocal flag set', () {
      final connection = AgentConnection(
        id: 'c1',
        profile: profile,
        service: service,
        sessions: const <Session>[],
        isConnected: true,
        isLocal: true,
      );

      expect(connection.isLocal, isTrue);
    });
  });

  group('ConfigService agent directory', () {
    test('persists and loads last directory', () async {
      await ConfigService.saveAgentLastDirectory('D:/repos/test');
      expect(await ConfigService.getAgentLastDirectory(), 'D:/repos/test');
    });
  });
}

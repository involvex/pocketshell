import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:opencode_api/opencode_api.dart';

class OpenCodeConnectionService {
  OpenCodeConnectionService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;

  late final Dio _dio;
  late final Opencode _client;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Opencode get client => _client;

  Future<void> connect() async {
    _dio = Opencode.createDio(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
    _client = Opencode(dio: _dio);
    await checkHealth();
    // ignore: unawaited_futures
    _listenToEvents();
  }

  Future<HealthResponse> checkHealth() async {
    return _client.global.getHealth();
  }

  Future<String?> getServerPath() async {
    final pathResponse = await _client.path.getPath();
    return pathResponse.path;
  }

  Future<List<Session>> getSessions({String? directory}) async {
    if (directory == null || directory.isEmpty) {
      return _client.session.getSessions();
    }

    final response = await _dio.get<List<dynamic>>(
      '/session',
      queryParameters: <String, dynamic>{'directory': directory},
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((dynamic item) => Session.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Session> createSession({String? title, String? directory}) async {
    if (directory == null || directory.isEmpty) {
      return _client.session.createSession(
        title != null ? <String, dynamic>{'title': title} : <String, dynamic>{},
      );
    }

    final body = <String, dynamic>{'directory': directory};
    if (title != null) {
      body['title'] = title;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/session',
      data: body,
      queryParameters: <String, dynamic>{'directory': directory},
    );
    return Session.fromJson(response.data!);
  }

  Future<void> deleteSession(String id) => _client.session.deleteSession(id);

  Future<List<MessageWithParts>> getMessages(String sessionId) {
    return _client.session.getMessages(sessionId);
  }

  Future<void> sendMessageAsync(String sessionId, String text) {
    return _client.session.sendMessageAsyncRaw(
      sessionId,
      <String, dynamic>{
        'parts': <Map<String, String>>[
          {'type': 'text', 'text': text},
        ],
      },
    );
  }

  Future<List<Command>> getCommands() => _client.commands.getCommands();

  Future<List<Agent>> getAgents() => _client.agents.getAgents();

  Future<ProviderListResponse> getProviders() => _client.provider.getProviders();

  Future<ConfigProvidersResponse> getConfigProviders() =>
      _client.config.getConfigProviders();

  Future<bool> setProviderAuth(
    String providerId,
    Map<String, dynamic> body,
  ) =>
      _client.auth.setAuth(providerId, body);

  Future<void> executeCommand(String sessionId, String command) async {
    await _client.session.executeCommand(
      sessionId,
      <String, dynamic>{'command': command},
    );
  }

  Future<bool> respondToPermission(
    String sessionId,
    String permissionId, {
    required String response,
    bool remember = false,
  }) {
    return _client.session.respondToPermissionRequest(
      sessionId,
      permissionId,
      <String, dynamic>{
        'response': response,
        'remember': remember,
      },
    );
  }

  Future<void> _listenToEvents() async {
    try {
      final response = await _dio.get<ResponseBody>(
        '/event',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
      );

      final stream = response.data?.stream;
      if (stream == null || _disposed) return;

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        if (_disposed) break;
        buffer.write(utf8.decode(chunk));
        final content = buffer.toString();
        final lines = content.split('\n');
        buffer.clear();
        if (!content.endsWith('\n') && lines.isNotEmpty) {
          buffer.write(lines.removeLast());
        }
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;
            try {
              final event = json.decode(data) as Map<String, dynamic>;
              if (!_eventController.isClosed) {
                _eventController.add(event);
              }
            } catch (_) {
              // Skip malformed SSE payloads
            }
          }
        }
      }
    } catch (_) {
      // Stream ended or failed
    }
  }

  void dispose() {
    _disposed = true;
    _eventController.close();
  }
}

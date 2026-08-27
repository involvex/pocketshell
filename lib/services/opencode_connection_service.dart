import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:opencode_api/opencode_api.dart';

enum ConnectionEventType { disconnected }

class ConnectionEvent {
  const ConnectionEvent(this.type);

  final ConnectionEventType type;
}

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
  final StreamController<ConnectionEvent> _connectionEventController =
      StreamController<ConnectionEvent>.broadcast();

  bool _disposed = false;
  bool _listening = false;
  StreamSubscription<List<int>>? _sseSubscription;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventController.stream;

  bool get isEventStreamActive => _listening;

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

  Future<ConfigResponse> getConfig() => _client.config.getConfig();

  Future<ConfigResponse> updateConfig(Map<String, dynamic> body) =>
      _client.config.updateConfig(body);

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

  Future<ProviderListResponse> getProviders() =>
      _client.provider.getProviders();

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

  Future<void> reconnectEvents() async {
    if (_disposed) return;
    await _stopEventStream();
    _reconnectAttempts = 0;
    await _listenToEvents();
  }

  Future<void> reconnectEventsIfNeeded() async {
    if (_disposed || _listening) return;
    await reconnectEvents();
  }

  Future<void> _listenToEvents() async {
    if (_disposed || _listening) return;
    _listening = true;

    try {
      final response = await _dio.get<ResponseBody>(
        '/event',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
      );

      final stream = response.data?.stream;
      if (stream == null || _disposed) {
        _listening = false;
        return;
      }

      // Use utf8 decoder streaming to handle multi-byte boundaries correctly
      final pending = StringBuffer();

      _sseSubscription = stream.listen(
        (List<int> chunk) {
          if (_disposed) return;
          // Use allowMalformed to handle split multi-byte sequences
          pending.write(utf8.decode(chunk, allowMalformed: true));
          final content = pending.toString();
          final lines = content.split('\n');
          pending.clear();
          // Keep incomplete last line in buffer
          if (!content.endsWith('\n') && lines.isNotEmpty) {
            pending.write(lines.removeLast());
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
        },
        onDone: _handleStreamEnded,
        onError: (Object error, StackTrace stackTrace) {
          _handleStreamEnded();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _listening = false;
      _handleStreamEnded();
      _scheduleReconnect();
    }
  }

  void _handleStreamEnded() {
    _listening = false;
    if (_disposed || _connectionEventController.isClosed) return;
    _connectionEventController.add(
      const ConnectionEvent(ConnectionEventType.disconnected),
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _listening) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // Max attempts reached, stop trying
      return;
    }
    _reconnectAttempts++;
    final delay = _baseReconnectDelay * _reconnectAttempts;
    Future.delayed(delay, () {
      if (!_disposed && !_listening) {
        // ignore: unawaited_futures
        _listenToEvents();
      }
    });
  }

  Future<void> _stopEventStream() async {
    _listening = false;
    await _sseSubscription?.cancel();
    _sseSubscription = null;
  }

  void dispose() {
    _disposed = true;
    // ignore: unawaited_futures
    _stopEventStream();
    _eventController.close();
    _connectionEventController.close();
  }
}

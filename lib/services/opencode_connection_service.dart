import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:opencode_api/opencode_api.dart';

import 'opencode_v2_mappers.dart';

enum ConnectionEventType { disconnected }

class ConnectionEvent {
  const ConnectionEvent(this.type);

  final ConnectionEventType type;
}

/// OpenCode HTTP client for server V2 (`/api/*` + Basic auth).
///
/// Adapts responses into the V1 `opencode_api` model types the UI already uses.
class OpenCodeConnectionService {
  OpenCodeConnectionService({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.allowInsecureTls = false,
  });

  final String baseUrl;
  final String username;
  final String password;

  /// When true, accepts self-signed / untrusted TLS certificates (LAN HTTPS).
  final bool allowInsecureTls;

  late final Dio _dio;
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

  String get _normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<void> connect() async {
    if (password.isEmpty) {
      throw StateError(
        'OpenCode password is required. Set the agent password on the profile '
        '(default username is "opencode").',
      );
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: _normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, dynamic>{
          'authorization':
              'Basic ${base64Encode(utf8.encode('$username:$password'))}',
          'accept': 'application/json',
        },
        validateStatus: (int? status) =>
            status != null && status >= 200 && status < 500,
      ),
    );

    if (allowInsecureTls) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          // Keep parity with prior debug logging without depending on package logger.
          assert(() {
            // ignore: avoid_print
            print('[DEBUG] API Request: ${options.method} ${options.uri}');
            return true;
          }());
          return handler.next(options);
        },
        onResponse:
            (Response<dynamic> response, ResponseInterceptorHandler handler) {
          assert(() {
            // ignore: avoid_print
            print(
              '[INFO] API Response: ${response.statusCode} for '
              '${response.requestOptions.path}',
            );
            return true;
          }());
          return handler.next(response);
        },
      ),
    );

    await checkHealth();
    // ignore: unawaited_futures
    _listenToEvents();
  }

  Future<HealthResponse> checkHealth() async {
    final response = await _dio.get<dynamic>('/api/info');
    _throwIfUnauthorized(response);
    _throwIfNotJsonApi(response, path: '/api/info');

    final body = response.data;
    if (body is! Map) {
      throw StateError('OpenCode /api/info returned an unexpected payload.');
    }
    final map = Map<String, dynamic>.from(body);
    final version = map['version'] as String?;
    if (version == null || version.isEmpty) {
      throw StateError(
        'OpenCode /api/info missing version — is this an OpenCode V2 server?',
      );
    }
    return HealthResponse(healthy: true, version: version);
  }

  Future<ConfigResponse> getConfig() async {
    final response = await _dio.get<dynamic>('/api/config');
    _ensureOk(response);
    final entries = unwrapV2ObjectList(response.data);
    Map<String, dynamic>? info;
    for (final entry in entries) {
      if (entry['type'] == 'document') {
        final candidate = entry['info'];
        if (candidate is Map) {
          info = Map<String, dynamic>.from(candidate);
          break;
        }
      }
    }

    final defaults = defaultsFromV2ConfigInfo(info);
    final providers = <String, dynamic>{};
    for (final entry in defaults.entries) {
      providers[entry.key] = <String, dynamic>{'default': entry.value};
    }

    return ConfigResponse(
      providers: providers.isEmpty ? info : providers,
      defaultModels:
          defaults.isEmpty ? null : Map<String, dynamic>.from(defaults),
    );
  }

  Future<ConfigResponse> updateConfig(Map<String, dynamic> body) async {
    // V2 only exposes an experimental shell patch; keep a clear failure path.
    if (body.containsKey('shell')) {
      final response = await _dio.patch<dynamic>(
        '/api/experimental/config',
        data: <String, dynamic>{'shell': body['shell']},
      );
      _ensureOk(response);
      return getConfig();
    }
    throw UnsupportedError(
      'OpenCode V2 does not support arbitrary config PATCH via HTTP. '
      'Edit opencode.json on the host or use SSH import.',
    );
  }

  Future<String?> getServerPath() async {
    final response = await _dio.get<dynamic>('/api/info');
    _ensureOk(response);
    final body = response.data;
    if (body is! Map) return null;
    final paths = body['paths'];
    if (paths is Map) {
      return paths['tmp'] as String?;
    }
    return null;
  }

  Future<List<Session>> getSessions({String? directory}) async {
    final query = <String, dynamic>{
      'order': 'desc',
      if (directory != null && directory.isNotEmpty) 'directory': directory,
    };
    final response = await _dio.get<dynamic>(
      '/api/session',
      queryParameters: query,
    );
    _ensureOk(response);
    return unwrapV2ObjectList(response.data).map(mapV2Session).toList();
  }

  Future<Session> createSession({String? title, String? directory}) async {
    final body = <String, dynamic>{};
    if (title != null && title.isNotEmpty) {
      body['title'] = title;
    }
    if (directory != null && directory.isNotEmpty) {
      body['location'] = <String, dynamic>{'directory': directory};
    }

    final response = await _dio.post<dynamic>('/api/session', data: body);
    _ensureOk(response);
    final data = unwrapV2Data(response.data);
    if (data is! Map) {
      throw StateError('OpenCode create session returned no session object.');
    }
    return mapV2Session(Map<String, dynamic>.from(data));
  }

  Future<void> deleteSession(String id) async {
    final response = await _dio.delete<dynamic>('/api/session/$id');
    _ensureOk(response);
  }

  Future<List<MessageWithParts>> getMessages(String sessionId) async {
    final response = await _dio.get<dynamic>('/api/session/$sessionId/message');
    _ensureOk(response);
    final messages =
        unwrapV2ObjectList(response.data).map(mapV2Message).toList();
    // V2 returns newest-first; chat UI expects oldest-first.
    return messages.reversed.toList();
  }

  Future<void> sendMessageAsync(String sessionId, String text) async {
    final response = await _dio.post<dynamic>(
      '/api/session/$sessionId/prompt',
      data: <String, dynamic>{'text': text},
    );
    _ensureOk(response);
  }

  Future<List<Command>> getCommands() async {
    final response = await _dio.get<dynamic>('/api/command');
    _ensureOk(response);
    return unwrapV2ObjectList(response.data).map(mapV2Command).toList();
  }

  Future<List<Agent>> getAgents() async {
    final response = await _dio.get<dynamic>('/api/agent');
    _ensureOk(response);
    return unwrapV2ObjectList(response.data).map(mapV2Agent).toList();
  }

  Future<ProviderListResponse> getProviders() async {
    final providersResponse = await _dio.get<dynamic>('/api/provider');
    _ensureOk(providersResponse);
    final connectedIds = await _connectedIntegrationIds();
    final providers = unwrapV2ObjectList(providersResponse.data)
        .map(
          (Map<String, dynamic> json) => mapV2Provider(
            json,
            connectedIds: connectedIds,
          ),
        )
        .toList();

    final config = await getConfig();
    final defaults = <String, String>{};
    final rawDefaults = config.defaultModels;
    if (rawDefaults != null) {
      for (final entry in rawDefaults.entries) {
        final value = entry.value;
        if (value is String && value.isNotEmpty) {
          defaults[entry.key] = value;
        }
      }
    }

    return mapV2ProviderList(
      providers: providers,
      defaults: defaults,
      connected: connectedIds.toList()..sort(),
    );
  }

  Future<ConfigProvidersResponse> getConfigProviders() async {
    final providerList = await getProviders();
    return ConfigProvidersResponse(
      providers: providerList.all,
      default_: providerList.default_,
    );
  }

  Future<bool> setProviderAuth(
    String providerId,
    Map<String, dynamic> body,
  ) async {
    final key = body['key'] as String? ?? body['apiKey'] as String?;
    if (key == null || key.isEmpty) {
      throw ArgumentError('Provider API key is required.');
    }

    final response = await _dio.post<dynamic>(
      '/api/credential',
      data: <String, dynamic>{
        'integrationID': providerId,
        'activate': true,
        'value': <String, dynamic>{
          'type': 'key',
          'key': key,
        },
      },
    );
    _ensureOk(response);
    return true;
  }

  Future<void> executeCommand(String sessionId, String command) async {
    final parsed = parseSlashCommand(command);
    if (parsed.name.isEmpty) {
      throw ArgumentError('Command name is empty.');
    }
    final response = await _dio.post<dynamic>(
      '/api/session/$sessionId/command',
      data: <String, dynamic>{
        'name': parsed.name,
        'text': parsed.text,
      },
    );
    _ensureOk(response);
  }

  Future<bool> respondToPermission(
    String sessionId,
    String permissionId, {
    required String response,
    bool remember = false,
  }) async {
    final decision = mapPermissionDecision(response, remember: remember);
    final apiResponse = await _dio.post<dynamic>(
      '/api/session/$sessionId/permission/$permissionId/reply',
      data: <String, dynamic>{'decision': decision},
    );
    _ensureOk(apiResponse);
    return true;
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

  Future<Set<String>> _connectedIntegrationIds() async {
    try {
      final response = await _dio.get<dynamic>('/api/credential');
      if (response.statusCode != 200) {
        return const <String>{};
      }
      final ids = <String>{};
      for (final item in unwrapV2ObjectList(response.data)) {
        final active = item['active'] as bool? ?? true;
        if (!active) continue;
        final id = item['integrationID'] as String?;
        if (id != null && id.isNotEmpty) {
          ids.add(id);
        }
      }
      return ids;
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> _listenToEvents() async {
    if (_disposed || _listening) return;
    _listening = true;

    try {
      final response = await _dio.get<ResponseBody>(
        '/api/event',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: <String, dynamic>{'accept': 'text/event-stream'},
        ),
      );

      if (response.statusCode == 401) {
        _listening = false;
        throw StateError(
          'OpenCode rejected event stream credentials (401). '
          'Check agent username/password.',
        );
      }

      final stream = response.data?.stream;
      if (stream == null || _disposed) {
        _listening = false;
        return;
      }

      final pending = StringBuffer();

      _sseSubscription = stream.listen(
        (List<int> chunk) {
          if (_disposed) return;
          pending.write(utf8.decode(chunk, allowMalformed: true));
          final content = pending.toString();
          final lines = content.split('\n');
          pending.clear();
          if (!content.endsWith('\n') && lines.isNotEmpty) {
            pending.write(lines.removeLast());
          }
          for (final line in lines) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;
            try {
              final decoded = json.decode(data);
              if (decoded is! Map) continue;
              final event = normalizeV2Event(
                Map<String, dynamic>.from(decoded),
              );
              if (!_eventController.isClosed) {
                _eventController.add(event);
              }
            } catch (_) {
              // Skip malformed SSE payloads
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

  void _throwIfUnauthorized(Response<dynamic> response) {
    if (response.statusCode == 401) {
      throw StateError(
        'OpenCode authentication failed (401). '
        'Check agent username/password for $baseUrl.',
      );
    }
  }

  void _throwIfNotJsonApi(Response<dynamic> response, {required String path}) {
    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      throw StateError(
        'OpenCode returned HTML for $path instead of JSON. '
        'Use the OpenCode serve API port and Basic auth '
        '(V2 routes are under /api/*).',
      );
    }
    if (response.statusCode != null &&
        response.statusCode! >= 400 &&
        response.statusCode != 401) {
      throw StateError(
        'OpenCode $path failed with HTTP ${response.statusCode}.',
      );
    }
  }

  void _ensureOk(Response<dynamic> response) {
    _throwIfUnauthorized(response);
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return;
    }
    final body = response.data;
    var detail = '';
    if (body is Map && body['message'] is String) {
      detail = ': ${body['message']}';
    }
    throw StateError(
      'OpenCode request failed (HTTP $status)$detail',
    );
  }

  void dispose() {
    _disposed = true;
    // ignore: unawaited_futures
    _stopEventStream();
    _eventController.close();
    _connectionEventController.close();
  }
}

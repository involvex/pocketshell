import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_provider.dart';

class AiGatewayException implements Exception {
  AiGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiGatewayService {
  static const String opencodeZenBaseUrl = 'https://opencode.ai/zen/v1';
  static const String kiloGatewayBaseUrl = 'https://api.kilo.ai/api/gateway';

  static const String defaultOpencodeModel =
      AiProviderDefaults.opencodeZenModel;
  static const String defaultKiloModel = AiProviderDefaults.kiloModel;

  static const int _maxContextChars = 4000;
  static const Duration _retryDelay = Duration(seconds: 2);

  static late final Dio _opencodeDio;
  static late final Dio _kiloDio;
  static bool _initialized = false;

  static String baseUrlFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.opencodeZen => opencodeZenBaseUrl,
      AiProvider.kiloGateway => kiloGatewayBaseUrl,
    };
  }

  static String defaultModelFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.opencodeZen => defaultOpencodeModel,
      AiProvider.kiloGateway => defaultKiloModel,
    };
  }

  static void _initDioClients() {
    if (_initialized) return;

    final opencodeHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'x-opencode-client': 'cli',
    };
    _opencodeDio = Dio(
      BaseOptions(
        baseUrl: opencodeZenBaseUrl,
        headers: opencodeHeaders,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    final kiloHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    _kiloDio = Dio(
      BaseOptions(
        baseUrl: kiloGatewayBaseUrl,
        headers: kiloHeaders,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    // Add retry interceptor
    final retryInterceptor = InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error)) {
          await Future.delayed(_retryDelay);
          return handler.resolve(await _retryRequest(error));
        }
        handler.next(error);
      },
    );
    _opencodeDio.interceptors.add(retryInterceptor);
    _kiloDio.interceptors.add(retryInterceptor);

    _initialized = true;
  }

  static bool _shouldRetry(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    if (error.response?.statusCode != null) {
      final code = error.response!.statusCode!;
      return code >= 500 || code == 429;
    }
    return false;
  }

  static Future<Response<dynamic>> _retryRequest(DioException error) {
    final options = error.requestOptions;
    final dio = options.baseUrl == opencodeZenBaseUrl ? _opencodeDio : _kiloDio;
    return dio.fetch(options);
  }

  static Dio _getDio(AiProvider provider) {
    _initDioClients();
    return provider == AiProvider.opencodeZen ? _opencodeDio : _kiloDio;
  }

  static Future<List<String>> fetchModels({
    required AiProvider provider,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw AiGatewayException('API key is required for the selected provider');
    }

    final dio = _getDio(provider);
    final authOptions = Options(headers: {'Authorization': 'Bearer $apiKey'});

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/models',
        options: authOptions,
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw AiGatewayException('Unexpected models response format');
      }
      final models = data
          .map((entry) {
            if (entry is Map<String, dynamic>) {
              return entry['id'] as String?;
            }
            if (entry is Map) {
              return Map<String, dynamic>.from(entry)['id'] as String?;
            }
            return null;
          })
          .whereType<String>()
          .toList();
      if (models.isEmpty) {
        throw AiGatewayException('No models returned from provider');
      }
      return models;
    } on DioException catch (e) {
      throw AiGatewayException(_dioMessage(e));
    }
  }

  static Future<String> generateCommand({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String userPrompt,
    String? terminalContext,
    CancelToken? cancelToken,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamCommand(
      provider: provider,
      apiKey: apiKey,
      model: model,
      userPrompt: userPrompt,
      terminalContext: terminalContext,
      cancelToken: cancelToken,
    )) {
      buffer.write(chunk);
    }

    final command = _stripCommand(buffer.toString());
    if (command.isEmpty) {
      throw AiGatewayException('AI returned an empty command');
    }
    return command;
  }

  static Stream<String> streamCommand({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String userPrompt,
    String? terminalContext,
    CancelToken? cancelToken,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw AiGatewayException('API key is required for the selected provider');
    }
    if (userPrompt.trim().isEmpty) {
      throw AiGatewayException('Describe the command you want to generate');
    }

    final dio = _getDio(provider);

    // Truncate terminal context to prevent token blow-up
    final truncatedContext =
        terminalContext != null && terminalContext.isNotEmpty
            ? _truncateContext(terminalContext)
            : null;

    final contextBlock = truncatedContext != null
        ? '\n\nRecent terminal output:\n$truncatedContext'
        : '';

    try {
      final response = await dio.post<ResponseBody>(
        '/chat/completions',
        cancelToken: cancelToken,
        data: <String, dynamic>{
          'model': model,
          'stream': true,
          'messages': <Map<String, String>>[
            {
              'role': 'system',
              'content':
                  'You generate shell commands for SSH terminals. Return only '
                      'a single command with no markdown, no explanation, and no '
                      'code fences.',
            },
            {
              'role': 'user',
              'content': '$userPrompt$contextBlock',
            },
          ],
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw AiGatewayException('No response body from AI provider');
      }

      yield* _parseSseStream(body.stream);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      }
      throw AiGatewayException(_dioMessage(e));
    }
  }

  static String _truncateContext(String context) {
    if (context.length <= _maxContextChars) return context;
    return context.substring(context.length - _maxContextChars);
  }

  static Stream<String> _parseSseStream(Stream<List<int>> byteStream) async* {
    final pending = StringBuffer();

    await for (final bytes in byteStream) {
      // Use utf8.decode with allowMalformed to handle multi-byte boundaries
      pending.write(utf8.decode(bytes, allowMalformed: true));
      var content = pending.toString();

      while (true) {
        final separatorIndex = content.indexOf('\n\n');
        if (separatorIndex == -1) {
          break;
        }

        final eventBlock = content.substring(0, separatorIndex);
        content = content.substring(separatorIndex + 2);
        pending
          ..clear()
          ..write(content);

        for (final line in eventBlock.split('\n')) {
          if (!line.startsWith('data:')) {
            continue;
          }
          final payload = line.substring(5).trim();
          if (payload.isEmpty) {
            continue;
          }
          if (payload == '[DONE]') {
            return;
          }

          // Handle error events
          if (payload.startsWith('{')) {
            try {
              final decoded = jsonDecode(payload);
              if (decoded is Map &&
                  decoded['error'] is Map &&
                  decoded['error']['message'] is String) {
                throw AiGatewayException(
                    'AI provider error: ${decoded['error']['message']}');
              }
            } catch (_) {
              // Not a JSON error event, continue
            }
          }

          final delta = _extractDeltaContent(payload);
          if (delta != null && delta.isNotEmpty) {
            yield delta;
          }
        }
      }
    }
    // Flush any remaining content
    final remaining = pending.toString();
    if (remaining.isNotEmpty) {
      for (final line in remaining.split('\n')) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isNotEmpty && payload != '[DONE]') {
            final delta = _extractDeltaContent(payload);
            if (delta != null && delta.isNotEmpty) {
              yield delta;
            }
          }
        }
      }
    }
  }

  static String? _extractDeltaContent(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final choices = Map<String, dynamic>.from(decoded)['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }
      final first = choices.first;
      if (first is! Map) {
        return null;
      }
      final delta = Map<String, dynamic>.from(first)['delta'];
      if (delta is! Map) {
        return null;
      }
      final content = Map<String, dynamic>.from(delta)['content'];
      return content is String ? content : null;
    } catch (_) {
      return null;
    }
  }

  static String _stripCommand(String raw) {
    var command = raw.trim();
    if (command.startsWith('```')) {
      // Handle ```lang\ncontent\n``` or ```\ncontent\n``` with optional lang
      command = command.replaceFirst(RegExp(r'^```\w*\s*\n?'), '');
      command = command.replaceFirst(RegExp(r'\n?\s*```$'), '');
    }
    return command.trim();
  }

  static String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final errorBody = Map<String, dynamic>.from(data);
      final message = errorBody['error'];
      if (message is Map) {
        final msg = Map<String, dynamic>.from(message)['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (message is String && message.isNotEmpty) return message;
    }
    return error.message ?? 'AI request failed';
  }
}

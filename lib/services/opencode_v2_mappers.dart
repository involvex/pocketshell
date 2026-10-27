import 'package:opencode_api/opencode_api.dart';

/// Normalizes an OpenCode V2 `{data: ...}` envelope into the inner payload.
dynamic unwrapV2Data(dynamic body) {
  if (body is Map) {
    final map = Map<String, dynamic>.from(body);
    if (map.containsKey('data')) {
      return map['data'];
    }
  }
  return body;
}

/// Extracts a list from a V2 response body (`{data: [...]}` or bare list).
List<Map<String, dynamic>> unwrapV2ObjectList(dynamic body) {
  final unwrapped = unwrapV2Data(body);
  if (unwrapped is! List) {
    return const <Map<String, dynamic>>[];
  }
  return unwrapped
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item),
      )
      .toList();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _dateFromEpoch(dynamic value) {
  final millis = _asInt(value);
  if (millis == null) return null;
  final normalized = millis > 9999999999 ? millis : millis * 1000;
  return DateTime.fromMillisecondsSinceEpoch(normalized);
}

/// Maps a V2 Session.Info object into the V1 [Session] UI model.
Session mapV2Session(Map<String, dynamic> json) {
  final location = json['location'];
  String? directory;
  if (location is Map) {
    directory = location['directory'] as String?;
  }

  final time = json['time'];
  SessionTime? sessionTime;
  if (time is Map) {
    sessionTime = SessionTime(
      created: _asInt(time['created']),
      updated: _asInt(time['updated']),
    );
  }

  return Session(
    id: json['id'] as String?,
    projectID: json['projectID'] as String?,
    directory: directory,
    title: json['title'] as String?,
    parentID: json['parentID'] as String?,
    time: sessionTime,
  );
}

String _roleFromV2MessageType(String? type) {
  return switch (type) {
    'user' => 'user',
    'assistant' => 'assistant',
    'system' => 'system',
    'synthetic' => 'system',
    'shell' => 'assistant',
    _ => type ?? 'unknown',
  };
}

String _toolPartText(Map<String, dynamic> tool) {
  final name = tool['name'] as String? ?? 'tool';
  final state = tool['state'];
  final buffer = StringBuffer(name);
  if (state is Map) {
    final status = state['status'] as String?;
    if (status != null && status.isNotEmpty) {
      buffer.write(' ($status)');
    }
    final input = state['input'];
    if (input != null) {
      buffer.write('\n$input');
    }
    final output = state['output'] ?? state['error'];
    if (output != null) {
      buffer.write('\n$output');
    }
  }
  return buffer.toString();
}

List<MessagePart> _partsFromV2Message(Map<String, dynamic> json) {
  final type = json['type'] as String? ?? '';
  final id = json['id'] as String? ?? 'msg';

  if (type == 'user' || type == 'system' || type == 'synthetic') {
    final text = json['text'] as String? ?? '';
    final description = json['description'] as String?;
    final body = description == null || description.isEmpty
        ? text
        : '$description\n$text';
    return <MessagePart>[
      MessagePart(id: '$id-text', type: 'text', text: body),
    ];
  }

  if (type == 'shell') {
    final text = json['text'] as String? ?? json['command'] as String? ?? '';
    return <MessagePart>[
      MessagePart(id: '$id-shell', type: 'text', text: text),
    ];
  }

  final content = json['content'];
  if (content is! List) {
    final fallback = json['text'] as String?;
    if (fallback == null || fallback.isEmpty) {
      return const <MessagePart>[];
    }
    return <MessagePart>[
      MessagePart(id: '$id-text', type: 'text', text: fallback),
    ];
  }

  final parts = <MessagePart>[];
  for (var i = 0; i < content.length; i++) {
    final item = content[i];
    if (item is! Map) continue;
    final part = Map<String, dynamic>.from(item);
    final partType = part['type'] as String? ?? 'text';
    final partId = part['id'] as String? ?? '$id-$i';

    if (partType == 'tool') {
      parts.add(
        MessagePart(
          id: partId,
          type: 'tool',
          text: _toolPartText(part),
          content: _toolPartText(part),
        ),
      );
      continue;
    }

    final text = part['text'] as String? ?? '';
    parts.add(
      MessagePart(
        id: partId,
        type: partType,
        text: text,
        content: text,
      ),
    );
  }
  return parts;
}

/// Maps a V2 Session.Message.Info object into [MessageWithParts].
MessageWithParts mapV2Message(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  final time = json['time'];
  DateTime? createdAt;
  if (time is Map) {
    createdAt = _dateFromEpoch(time['created']);
  }

  return MessageWithParts(
    info: Message(
      id: json['id'] as String?,
      role: _roleFromV2MessageType(type),
      createdAt: createdAt,
      content: json['text'] as String?,
    ),
    parts: _partsFromV2Message(json),
  );
}

/// Maps V2 Command.Info into V1 [Command].
Command mapV2Command(Map<String, dynamic> json) {
  final name = json['name'] as String?;
  return Command(
    id: name,
    name: name,
    description: json['description'] as String?,
  );
}

/// Maps V2 Agent.Info into V1 [Agent].
Agent mapV2Agent(Map<String, dynamic> json) {
  return Agent(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    category: json['mode'] as String?,
  );
}

/// Maps V2 Provider.Info into V1 [Provider].
Provider mapV2Provider(
  Map<String, dynamic> json, {
  Set<String> connectedIds = const <String>{},
}) {
  final id = json['id'] as String?;
  final integrationId = json['integrationID'] as String? ?? id;
  final connected =
      integrationId != null && connectedIds.contains(integrationId);
  return Provider(
    id: id,
    name: json['name'] as String?,
    description: json['package'] as String?,
    connected: connected,
  );
}

/// Builds provider list response used by model/slash helpers.
ProviderListResponse mapV2ProviderList({
  required List<Provider> providers,
  required Map<String, String> defaults,
  required List<String> connected,
}) {
  return ProviderListResponse(
    all: providers,
    default_: defaults.isEmpty ? null : defaults,
    connected: connected,
  );
}

/// Extracts default provider→model pairs from a V2 config document `info` map.
Map<String, String> defaultsFromV2ConfigInfo(Map<String, dynamic>? info) {
  final defaults = <String, String>{};
  if (info == null) return defaults;

  void addModel(dynamic model) {
    if (model is! Map) return;
    final providerId = model['providerID'] as String?;
    final modelId = model['model'] as String? ?? model['id'] as String?;
    if (providerId == null ||
        providerId.isEmpty ||
        modelId == null ||
        modelId.isEmpty) {
      return;
    }
    defaults[providerId] = modelId;
  }

  addModel(info['model']);

  final agents = info['agents'];
  if (agents is Map) {
    for (final value in agents.values) {
      if (value is Map) {
        addModel(value['model']);
      }
    }
  }

  return defaults;
}

/// Parses `/name args` into V2 command `{name, text}`.
({String name, String text}) parseSlashCommand(String command) {
  var trimmed = command.trim();
  if (trimmed.startsWith('/')) {
    trimmed = trimmed.substring(1);
  }
  final space = trimmed.indexOf(' ');
  if (space <= 0) {
    return (name: trimmed, text: '');
  }
  return (
    name: trimmed.substring(0, space).trim(),
    text: trimmed.substring(space + 1).trim(),
  );
}

/// Maps UI allow/deny (+ remember) to V2 Permission.Reply.
String mapPermissionDecision(String response, {required bool remember}) {
  final normalized = response.trim().toLowerCase();
  if (normalized == 'deny' ||
      normalized == 'reject' ||
      normalized == 'once-reject') {
    return 'reject';
  }
  if (remember || normalized == 'always') {
    return 'always';
  }
  return 'once';
}

/// Adapts a V2 SSE event into the shape AgentProvider already understands.
Map<String, dynamic> normalizeV2Event(Map<String, dynamic> event) {
  final normalized = Map<String, dynamic>.from(event);
  final data = event['data'];
  if (!normalized.containsKey('properties') && data is Map) {
    normalized['properties'] = Map<String, dynamic>.from(data);
  }

  final type = event['type'] as String?;
  if (type != null &&
      type.contains('permission') &&
      !type.contains('reply') &&
      !type.contains('list') &&
      !type.contains('saved')) {
    // Prefer a stable alias for the permission dialog handler.
    if (type != 'permission.asked') {
      normalized['type'] = 'permission.asked';
    }
    final rawProps = normalized['properties'];
    final props = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
    props['permissionID'] ??= props['id'];
    props['sessionID'] ??= props['sessionId'];
    props['message'] ??=
        props['description'] ?? props['action'] ?? props['message'];
    normalized['properties'] = props;
  }

  return normalized;
}

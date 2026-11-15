import 'dart:convert';
import 'dart:typed_data';

/// Pending file attached to an agent prompt, serialized for OpenCode V2
/// `POST /api/session/{id}/prompt` as `PromptInput.FileAttachment`.
///
/// OpenAPI requires each item to include a `uri`. Remote paths use the
/// server-local absolute path with `source: {type: uri, uri}`. Local bytes
/// are sent as a `data:<mime>;base64,...` URI (see opencode.ai/v2/openapi.json).
class AgentPromptAttachment {
  AgentPromptAttachment({
    required this.displayName,
    required this.apiPayload,
  });

  final String displayName;

  /// JSON object for the `files[]` array on `/prompt`.
  final Map<String, dynamic> apiPayload;

  factory AgentPromptAttachment.remotePath(String absolutePath) {
    final name = _basename(absolutePath);
    return AgentPromptAttachment(
      displayName: name,
      apiPayload: <String, dynamic>{
        'uri': absolutePath,
        'name': name,
        'source': <String, dynamic>{
          'type': 'uri',
          'uri': absolutePath,
        },
      },
    );
  }

  factory AgentPromptAttachment.localBytes({
    required String filename,
    required Uint8List bytes,
    String? mime,
  }) {
    final resolvedMime = mime ?? _guessMime(filename);
    final dataUri =
        'data:$resolvedMime;base64,${base64Encode(bytes)}';
    return AgentPromptAttachment(
      displayName: filename,
      apiPayload: <String, dynamic>{
        'uri': dataUri,
        'name': filename,
        'source': <String, dynamic>{'type': 'inline'},
      },
    );
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0 || index >= normalized.length - 1) {
      return path;
    }
    return normalized.substring(index + 1);
  }

  static String _guessMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.dart') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.js') ||
        lower.endsWith('.py') ||
        lower.endsWith('.rs') ||
        lower.endsWith('.go') ||
        lower.endsWith('.java') ||
        lower.endsWith('.kt') ||
        lower.endsWith('.c') ||
        lower.endsWith('.cpp') ||
        lower.endsWith('.h')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }
}

class AgentPromptSubmission {
  const AgentPromptSubmission({
    required this.text,
    this.attachments = const <AgentPromptAttachment>[],
  });

  final String text;
  final List<AgentPromptAttachment> attachments;
}
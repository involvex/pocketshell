import '../services/opencode_connection_service.dart';

class AgentPermissionRequest {
  const AgentPermissionRequest({
    required this.connectionId,
    required this.sessionId,
    required this.permissionId,
    required this.message,
    required this.service,
  });

  final String connectionId;
  final String sessionId;
  final String permissionId;
  final String message;
  final OpenCodeConnectionService service;
}

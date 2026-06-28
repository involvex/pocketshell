import 'package:opencode_api/opencode_api.dart';

import '../models/ssh_profile.dart';
import '../services/opencode_connection_service.dart';

class AgentConnection {
  AgentConnection({
    required this.id,
    required this.profile,
    required this.service,
    required this.sessions,
    required this.isConnected,
    this.activeSessionId,
    this.messages = const [],
    this.isLoadingMessages = false,
    this.isSending = false,
    this.isLocal = false,
    this.selectedDirectory,
  });

  final String id;
  final SSHProfile profile;
  final OpenCodeConnectionService service;
  List<Session> sessions;
  String? activeSessionId;
  List<MessageWithParts> messages;
  bool isConnected;
  bool isLoadingMessages;
  bool isSending;
  bool isLocal;
  String? selectedDirectory;
}

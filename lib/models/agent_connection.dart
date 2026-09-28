import 'dart:async';

import 'package:opencode_api/opencode_api.dart';

import '../models/agent_model_option.dart';
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
    this.availableCommands = const [],
    this.availableAgents = const [],
    this.modelOptions = const [],
    this.providerInfo,
    this.configProviders,
    this.selectedModelId,
    this.isLoadingMetadata = false,
    this.collapseToolParts = true,
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
  List<Command> availableCommands;
  List<Agent> availableAgents;
  List<AgentModelOption> modelOptions;
  ProviderListResponse? providerInfo;
  ConfigProvidersResponse? configProviders;
  String? selectedModelId;
  bool isLoadingMetadata;
  bool collapseToolParts;

  StreamSubscription<Map<String, dynamic>>? eventSub;
  StreamSubscription<ConnectionEvent>? connectionEventSub;

  void disposeSubscriptions() {
    unawaited(eventSub?.cancel());
    unawaited(connectionEventSub?.cancel());
    eventSub = null;
    connectionEventSub = null;
  }
}

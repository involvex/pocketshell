class AgentModelOption {
  const AgentModelOption({
    required this.providerId,
    required this.modelId,
  });

  final String providerId;
  final String modelId;

  String get commandValue => modelId.contains('/')
      ? modelId
      : '$providerId/$modelId';

  String get displayLabel => commandValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentModelOption &&
          providerId == other.providerId &&
          modelId == other.modelId;

  @override
  int get hashCode => Object.hash(providerId, modelId);
}

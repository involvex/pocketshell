enum AiProvider {
  opencodeZen,
  kiloGateway,
}

extension AiProviderLabels on AiProvider {
  String get displayName => switch (this) {
        AiProvider.opencodeZen => 'OpenCode Zen',
        AiProvider.kiloGateway => 'Kilo Gateway',
      };
}

class AiProviderDefaults {
  static const String opencodeZenModel = 'mimo-v2.5-free';
  static const String kiloModel = 'kilo-auto:free';
}

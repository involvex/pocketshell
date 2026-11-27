/// Optional terminal wand that calls opencode.ai / api.kilo.ai.
///
/// F-Droid ships with this enabled and declares **NonFreeNet**.
/// IzzyOnDroid rejects LLM front-ends — build with
/// `--dart-define=CLOUD_AI=false` to hide the wand and provider settings.
const bool kCloudAiEnabled = bool.fromEnvironment(
  'CLOUD_AI',
  defaultValue: true,
);

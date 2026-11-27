/// OpenCode Agents tab (self-hosted server UI).
///
/// F-Droid keeps this on. IzzyOnDroid's AI policy rejects LLM front-ends —
/// build with `--dart-define=AGENTS=false` together with `CLOUD_AI=false`.
const bool kAgentsEnabled = bool.fromEnvironment(
  'AGENTS',
  defaultValue: true,
);

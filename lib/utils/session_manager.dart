/// Terminal multiplexer / session manager attached at SSH connect time.
enum SessionManager {
  none,
  tmux,
  psmux,
  zellij,
  screen,
  byobu,
}

extension SessionManagerX on SessionManager {
  String get displayName => switch (this) {
        SessionManager.none => 'Default (None)',
        SessionManager.tmux => 'tmux',
        SessionManager.psmux => 'psmux',
        SessionManager.zellij => 'zellij',
        SessionManager.screen => 'screen',
        SessionManager.byobu => 'byobu',
      };

  /// Startup command to attach or create a session, or `null` when none.
  ///
  /// Only used when the profile has no explicit [startupCommand].
  String? get attachOrNewCommand => switch (this) {
        SessionManager.none => null,
        SessionManager.tmux => 'tmux attach || tmux new-session -A -s main',
        // Windows-oriented placeholder; adjust if your psmux CLI differs.
        SessionManager.psmux =>
          r'psmux attach -t main 2>$null; if (-not $?) { psmux new-session -s main }',
        SessionManager.zellij => 'zellij attach -c main',
        SessionManager.screen => 'screen -d -RR main',
        SessionManager.byobu => 'byobu',
      };

  static SessionManager fromStorage(String? value) {
    return SessionManager.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SessionManager.none,
    );
  }
}

/// Resolves the effective startup command for a profile.
///
/// When [startupCommand] is non-empty it wins. Otherwise the session manager
/// injects its attach-or-new command when not [SessionManager.none].
String? resolveStartupCommand({
  required SessionManager sessionManager,
  String? startupCommand,
}) {
  final trimmed = startupCommand?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  return sessionManager.attachOrNewCommand;
}

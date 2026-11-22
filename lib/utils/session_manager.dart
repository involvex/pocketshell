/// Terminal multiplexer / session manager attached at SSH connect time.
enum SessionManager {
  none,
  tmux,
  psmux,
  zellij,
  screen,
  byobu,
  wt,
}

extension SessionManagerX on SessionManager {
  String get displayName => switch (this) {
        SessionManager.none => 'Default (None)',
        SessionManager.tmux => 'tmux',
        SessionManager.psmux => 'psmux (unsupported)',
        SessionManager.zellij => 'zellij',
        SessionManager.screen => 'screen',
        SessionManager.byobu => 'byobu',
        SessionManager.wt => 'Windows Terminal (unsupported)',
      };

  /// Whether this manager can attach to the SSH PTY (not a desktop window).
  bool get isPtyCompatible => switch (this) {
        SessionManager.psmux || SessionManager.wt => false,
        _ => true,
      };

  /// Values shown in profile pickers. Keeps [psmux]/[wt] out of new picks
  /// while still deserializing legacy stored profiles.
  static List<SessionManager> get selectableValues => SessionManager.values
      .where((m) => m.isPtyCompatible)
      .toList(growable: false);

  /// Startup command to attach or create a session, or `null` when none.
  ///
  /// Only used when the profile has no explicit [startupCommand].
  /// [psmux] and [wt] return null — they do not attach to this PTY.
  String? get attachOrNewCommand => switch (this) {
        SessionManager.none => null,
        SessionManager.tmux => 'tmux attach || tmux new-session -A -s main',
        SessionManager.psmux => null,
        SessionManager.zellij => 'zellij attach -c main',
        SessionManager.screen => 'screen -d -RR main',
        SessionManager.byobu => 'byobu',
        SessionManager.wt => null,
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

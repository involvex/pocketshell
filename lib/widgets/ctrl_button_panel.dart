import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/utils/terminal_clipboard.dart';

/// Compact multi-row accessory keyboard for mobile SSH sessions.
///
/// `Ctrl`/`Alt` are one-shot toggles: arm one, then press any key — a panel
/// button or a normal soft-keyboard (Gboard) key — and the modifier applies
/// to that keypress before auto-releasing. Gboard interop works because
/// [SSHProvider] applies armed modifiers to the next terminal output.
class CtrlButtonPanel extends StatelessWidget {
  const CtrlButtonPanel({this.onAiGenerate, super.key});

  /// Opens the AI command overlay when the wand control is tapped.
  final VoidCallback? onAiGenerate;

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, ssh, child) {
        final active = ssh.activeSession;
        if (active == null || !active.isConnected) {
          return const SizedBox.shrink();
        }
        final bool ctrlArmed = ssh.pendingCtrl;
        final bool altArmed = ssh.pendingAlt;
        final bool ctrlLocked = ssh.lockedCtrl;
        final bool altLocked = ssh.lockedAlt;

        final ColorScheme colors = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (ctrlArmed || altArmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _modifierHint(
                      ctrlArmed,
                      altArmed,
                      ctrlLocked,
                      altLocked,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: ctrlLocked || altLocked
                          ? Colors.orangeAccent
                          : Colors.tealAccent,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (onAiGenerate != null)
                      _IconNavButton(
                        icon: Icons.auto_awesome,
                        tooltip: 'Generate command with AI',
                        color: colors.primary,
                        onTap: onAiGenerate!,
                      ),
                    _NavButton(
                      label: 'Esc',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.escape,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: 'Tab',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.tab,
                        ssh,
                      ),
                    ),
                    _ToggleButton(
                      label: 'Ctrl',
                      active: ctrlArmed,
                      locked: ctrlLocked,
                      onTap: ssh.togglePendingCtrl,
                    ),
                    _ToggleButton(
                      label: 'Alt',
                      active: altArmed,
                      locked: altLocked,
                      onTap: ssh.togglePendingAlt,
                    ),
                    _NavButton(
                      label: '←',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowLeft,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: '→',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowRight,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: '↑',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowUp,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: '↓',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowDown,
                        ssh,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _NavButton(
                      label: 'Home',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.home,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: 'End',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.end,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: 'PgUp',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.pageUp,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: 'PgDn',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.pageDown,
                        ssh,
                      ),
                    ),
                    _NavButton(
                      label: 'Ctrl+X',
                      onTap: () => _sendFixedCtrl(ssh, 24),
                    ),
                    _NavButton(
                      label: 'Ctrl+O',
                      onTap: () => _sendFixedCtrl(ssh, 15),
                    ),
                    _NavButton(
                      label: 'Ctrl+A',
                      onTap: () => _sendFixedCtrl(ssh, 1),
                    ),
                    _NavButton(
                      label: 'Ctrl+C',
                      onTap: () => _sendFixedCtrl(ssh, 3),
                    ),
                    _NavButton(
                      label: 'Ctrl+D',
                      onTap: () => _sendFixedCtrl(ssh, 4),
                    ),
                    _NavButton(
                      label: 'Ctrl+Z',
                      onTap: () => _sendFixedCtrl(ssh, 26),
                    ),
                    _NavButton(
                      label: 'Ctrl+L',
                      onTap: () => _sendFixedCtrl(ssh, 12),
                    ),
                    _NavButton(
                      label: 'Paste',
                      onTap: () => _pasteFromClipboard(context, ssh),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _modifierHint(
    bool ctrlArmed,
    bool altArmed,
    bool ctrlLocked,
    bool altLocked,
  ) {
    if (ctrlArmed && altArmed) {
      return ctrlLocked || altLocked
          ? 'Ctrl+Alt locked — tap to release'
          : 'Ctrl+Alt armed — type the next key';
    }
    if (ctrlArmed) {
      return ctrlLocked
          ? 'Ctrl locked — tap to release (double-tap to lock)'
          : 'Ctrl armed — type the next key (double-tap to lock)';
    }
    return altLocked
        ? 'Alt locked — tap to release (double-tap to lock)'
        : 'Alt armed — type the next key (double-tap to lock)';
  }

  static void _sendKey(Terminal terminal, TerminalKey key, SSHProvider ssh) {
    final bool ctrl = ssh.pendingCtrl;
    final bool alt = ssh.pendingAlt;
    final bool hadModifier = ctrl || alt;
    final bool handled = terminal.keyInput(
      key,
      ctrl: ctrl,
      alt: alt,
    );
    if (!handled && hadModifier) {
      // keytab has no encoding for some modifier combos (e.g. Ctrl+Tab).
      // Fall back to the raw control byte so the remote still gets input.
      if (key == TerminalKey.tab && ctrl) {
        ssh.sendControlCharacter(9);
      } else if (key == TerminalKey.escape) {
        ssh.sendControlCharacter(27);
      }
    }
    if (hadModifier) {
      ssh.clearPendingModifiers();
    }
  }

  static void _sendFixedCtrl(SSHProvider ssh, int charCode) {
    ssh.sendControlCharacter(charCode);
    ssh.clearPendingModifiers();
  }

  static Future<void> _pasteFromClipboard(
    BuildContext context,
    SSHProvider ssh,
  ) async {
    final text = await TerminalClipboard.readText();
    if (text == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    ssh.sendString(text);
  }
}

class _IconNavButton extends StatelessWidget {
  const _IconNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: color ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: locked
            ? Colors.orange.shade800
            : active
                ? Colors.teal.shade700
                : Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

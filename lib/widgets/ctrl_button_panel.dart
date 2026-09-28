import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/providers/ssh_provider.dart';

/// Compact multi-row accessory keyboard for mobile SSH sessions.
///
/// `Ctrl`/`Alt` are one-shot toggles: arm one, then press any key — a panel
/// button or a normal soft-keyboard (Gboard) key — and the modifier applies
/// to that keypress before auto-releasing. Gboard interop works because
/// [SSHProvider] applies armed modifiers to the next terminal output.
class CtrlButtonPanel extends StatelessWidget {
  const CtrlButtonPanel({super.key});

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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (ctrlArmed || altArmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    ctrlArmed && altArmed
                        ? 'Ctrl+Alt armed — type the next key'
                        : ctrlArmed
                            ? 'Ctrl armed — type the next key'
                            : 'Alt armed — type the next key',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.tealAccent,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                      onTap: ssh.togglePendingCtrl,
                    ),
                    _ToggleButton(
                      label: 'Alt',
                      active: altArmed,
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
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    // Do not trim — trailing newlines/spaces matter for scripts.
    ssh.sendString(text);
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
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
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
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? Colors.teal.shade700 : Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

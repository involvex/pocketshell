import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/providers/ssh_provider.dart';

/// Compact multi-row accessory keyboard for mobile SSH sessions.
class CtrlButtonPanel extends StatefulWidget {
  const CtrlButtonPanel({super.key});

  @override
  State<CtrlButtonPanel> createState() => _CtrlButtonPanelState();
}

class _CtrlButtonPanelState extends State<CtrlButtonPanel> {
  bool _ctrlSticky = false;
  bool _altSticky = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, ssh, child) {
        final active = ssh.activeSession;
        if (active == null || !active.isConnected) {
          return const SizedBox.shrink();
        }

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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _NavButton(
                      label: 'Esc',
                      onTap: () =>
                          active.terminal.keyInput(TerminalKey.escape),
                    ),
                    _NavButton(
                      label: 'Tab',
                      onTap: () => _sendKey(active.terminal, TerminalKey.tab),
                    ),
                    _ToggleButton(
                      label: 'Ctrl',
                      active: _ctrlSticky,
                      onTap: () => setState(() => _ctrlSticky = !_ctrlSticky),
                    ),
                    _ToggleButton(
                      label: 'Alt',
                      active: _altSticky,
                      onTap: () => setState(() => _altSticky = !_altSticky),
                    ),
                    _NavButton(
                      label: '←',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowLeft,
                      ),
                    ),
                    _NavButton(
                      label: '→',
                      onTap: () => _sendKey(
                        active.terminal,
                        TerminalKey.arrowRight,
                      ),
                    ),
                    _NavButton(
                      label: '↑',
                      onTap: () =>
                          _sendKey(active.terminal, TerminalKey.arrowUp),
                    ),
                    _NavButton(
                      label: '↓',
                      onTap: () =>
                          _sendKey(active.terminal, TerminalKey.arrowDown),
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
                      onTap: () =>
                          _sendKey(active.terminal, TerminalKey.home),
                    ),
                    _NavButton(
                      label: 'End',
                      onTap: () => _sendKey(active.terminal, TerminalKey.end),
                    ),
                    _NavButton(
                      label: 'PgUp',
                      onTap: () =>
                          _sendKey(active.terminal, TerminalKey.pageUp),
                    ),
                    _NavButton(
                      label: 'PgDn',
                      onTap: () =>
                          _sendKey(active.terminal, TerminalKey.pageDown),
                    ),
                    _NavButton(
                      label: 'Ctrl+A',
                      onTap: () => ssh.sendControlCharacter(1),
                    ),
                    _NavButton(
                      label: 'Ctrl+C',
                      onTap: () => ssh.sendControlCharacter(3),
                    ),
                    _NavButton(
                      label: 'Ctrl+D',
                      onTap: () => ssh.sendControlCharacter(4),
                    ),
                    _NavButton(
                      label: 'Ctrl+Z',
                      onTap: () => ssh.sendControlCharacter(26),
                    ),
                    _NavButton(
                      label: 'Ctrl+L',
                      onTap: () => ssh.sendControlCharacter(12),
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

  void _sendKey(Terminal terminal, TerminalKey key) {
    terminal.keyInput(
      key,
      ctrl: _ctrlSticky,
      alt: _altSticky,
    );
    if (_ctrlSticky || _altSticky) {
      setState(() {
        _ctrlSticky = false;
        _altSticky = false;
      });
    }
  }

  Future<void> _pasteFromClipboard(
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

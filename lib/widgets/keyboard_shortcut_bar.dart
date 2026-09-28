import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../models/keyboard_shortcut.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import 'ai_command_button.dart';
import 'connection_modal.dart';
import 'profile_manager.dart';
import 'network_discovery.dart';
import 'key_manager.dart';

class KeyboardShortcutBar extends StatefulWidget {
  final int? showRow;
  final bool forceShowOnMobile;

  const KeyboardShortcutBar(
      {super.key, this.showRow, this.forceShowOnMobile = false});

  @override
  State<KeyboardShortcutBar> createState() => _KeyboardShortcutBarState();
}

class _KeyboardShortcutBarState extends State<KeyboardShortcutBar> {
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (widget.forceShowOnMobile) {
      _isCollapsed = false;
    } else if (isMobile) {
      _isCollapsed = !settings.showMobileShortcutBar;
    }
  }

  void _toggleCollapsed() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  Widget _buildCollapseButton(BuildContext context, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggleCollapsed,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCollapsed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: 'Show shortcuts',
          child: _buildCollapseButton(context, Icons.expand_more),
        ),
      );
    }

    return Consumer2<SettingsProvider, SSHProvider>(
      builder: (context, settings, ssh, child) {
        if (!settings.isLoaded) {
          return const SizedBox.shrink();
        }

        final maxRow = settings.maxRow;
        final isMobile = Platform.isAndroid || Platform.isIOS;

        Widget buildRows() {
          if (widget.showRow != null) {
            final rowIndex =
                widget.showRow! <= maxRow ? widget.showRow! : maxRow;
            final shortcuts = settings.getShortcutsByRow(rowIndex);
            final active = ssh.activeSession;
            return _ShortcutRow(
              rowIndex: rowIndex,
              shortcuts: shortcuts,
              isConnected: active != null && active.isConnected,
              collapseButton: isMobile
                  ? _buildCollapseButton(context, Icons.expand_less)
                  : null,
            );
          }

          return Column(
            children: List.generate(maxRow + 1, (rowIndex) {
              final shortcuts = settings.getShortcutsByRow(rowIndex);
              return _ShortcutRow(
                rowIndex: rowIndex,
                shortcuts: shortcuts,
                isConnected: ssh.activeSession?.isConnected ?? false,
                collapseButton: (isMobile && rowIndex == 0)
                    ? _buildCollapseButton(context, Icons.expand_less)
                    : null,
              );
            }),
          );
        }

        return buildRows();
      },
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final int rowIndex;
  final List<KeyboardShortcut> shortcuts;
  final bool isConnected;
  final Widget? collapseButton;

  const _ShortcutRow({
    required this.rowIndex,
    required this.shortcuts,
    required this.isConnected,
    this.collapseButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirstRow = rowIndex == 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isFirstRow ? 6 : 4,
      ),
      decoration: BoxDecoration(
        border: isFirstRow
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...shortcuts.map((s) => _ShortcutChip(
                        shortcut: s,
                        isConnected: isConnected,
                      )),
                  if (isFirstRow && isConnected) const AiCommandButton(),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (collapseButton != null) collapseButton!,
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final KeyboardShortcut shortcut;
  final bool isConnected;

  const _ShortcutChip({
    required this.shortcut,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final chipBorder = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final descColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.only(right: 4, left: 0),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  shortcut.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  shortcut.description,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    color: descColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final ssh = context.read<SSHProvider>();
    final homeState = context.findAncestorStateOfType<State>();

    switch (shortcut.action) {
      case ShortcutAction.newConnection:
        if (homeState != null && homeState.mounted) {
          _showConnectionModal(homeState.context);
        }
        break;
      case ShortcutAction.profiles:
        if (homeState != null && homeState.mounted) {
          _showProfileManager(homeState.context);
        }
        break;
      case ShortcutAction.discovery:
        if (homeState != null && homeState.mounted) {
          _showNetworkDiscovery(homeState.context);
        }
        break;
      case ShortcutAction.keys:
        if (homeState != null && homeState.mounted) {
          _showKeyManager(homeState.context);
        }
        break;
      case ShortcutAction.tabChar:
        if (isConnected && shortcut.charCode != null) {
          if (ssh.hasPendingModifiers) {
            ssh.sendTerminalKey(
              TerminalKey.tab,
              ctrl: ssh.pendingCtrl,
              alt: ssh.pendingAlt,
            );
            ssh.clearPendingModifiers();
          } else {
            ssh.sendControlCharacter(shortcut.charCode!);
          }
        }
        break;
      case ShortcutAction.escapeKey:
        if (isConnected) {
          if (ssh.hasPendingModifiers) {
            ssh.sendTerminalKey(
              TerminalKey.escape,
              ctrl: ssh.pendingCtrl,
              alt: ssh.pendingAlt,
            );
            ssh.clearPendingModifiers();
          } else {
            ssh.sendTerminalKey(TerminalKey.escape);
          }
        }
        break;
      case ShortcutAction.ctrlC:
      case ShortcutAction.ctrlD:
      case ShortcutAction.ctrlZ:
      case ShortcutAction.ctrlL:
      case ShortcutAction.ctrlA:
      case ShortcutAction.ctrlB:
      case ShortcutAction.ctrlE:
      case ShortcutAction.ctrlF:
      case ShortcutAction.ctrlG:
      case ShortcutAction.ctrlH:
      case ShortcutAction.ctrlJ:
      case ShortcutAction.ctrlK:
      case ShortcutAction.ctrlN:
      case ShortcutAction.ctrlO:
      case ShortcutAction.ctrlP:
      case ShortcutAction.ctrlQ:
      case ShortcutAction.ctrlR:
      case ShortcutAction.ctrlS:
      case ShortcutAction.ctrlT:
      case ShortcutAction.ctrlU:
      case ShortcutAction.ctrlW:
      case ShortcutAction.ctrlX:
      case ShortcutAction.ctrlY:
        if (isConnected && shortcut.charCode != null) {
          ssh.sendControlCharacter(shortcut.charCode!);
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.ctrlV:
        if (isConnected) {
          _pasteFromClipboard(context, ssh);
        }
        break;
      case ShortcutAction.arrowUp:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.arrowUp,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.arrowDown:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.arrowDown,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.arrowRight:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.arrowRight,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.arrowLeft:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.arrowLeft,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.home:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.home,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
      case ShortcutAction.end:
        if (isConnected) {
          ssh.sendTerminalKey(
            TerminalKey.end,
            ctrl: ssh.pendingCtrl,
            alt: ssh.pendingAlt,
          );
          ssh.clearPendingModifiers();
        }
        break;
    }
  }

  Future<void> _pasteFromClipboard(
    BuildContext context,
    SSHProvider ssh,
  ) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    ssh.sendString(text);
  }

  void _showConnectionModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const ConnectionModal(),
    );
  }

  void _showProfileManager(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ProfileManager(),
    );
  }

  void _showNetworkDiscovery(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const NetworkDiscoverySheet(),
    );
  }

  void _showKeyManager(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const KeyManager(),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../models/keyboard_shortcut.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../utils/terminal_clipboard.dart';
import 'connection_modal.dart';
import 'profile_manager.dart';
import 'network_discovery.dart';
import 'key_manager.dart';

/// Delay before arrow-key hold starts auto-repeating.
const Duration kShortcutKeyRepeatInitialDelay = Duration(milliseconds: 400);

/// Interval between repeated arrow key sends while held.
const Duration kShortcutKeyRepeatInterval = Duration(milliseconds: 45);

bool shortcutActionSupportsKeyRepeat(ShortcutAction action) {
  switch (action) {
    case ShortcutAction.arrowLeft:
    case ShortcutAction.arrowRight:
    case ShortcutAction.arrowUp:
    case ShortcutAction.arrowDown:
      return true;
    case ShortcutAction.newConnection:
    case ShortcutAction.profiles:
    case ShortcutAction.discovery:
    case ShortcutAction.keys:
    case ShortcutAction.tabChar:
    case ShortcutAction.home:
    case ShortcutAction.end:
    case ShortcutAction.escapeKey:
    case ShortcutAction.ctrlA:
    case ShortcutAction.ctrlB:
    case ShortcutAction.ctrlC:
    case ShortcutAction.ctrlD:
    case ShortcutAction.ctrlE:
    case ShortcutAction.ctrlF:
    case ShortcutAction.ctrlG:
    case ShortcutAction.ctrlH:
    case ShortcutAction.ctrlJ:
    case ShortcutAction.ctrlK:
    case ShortcutAction.ctrlL:
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
    case ShortcutAction.ctrlZ:
    case ShortcutAction.ctrlV:
      return false;
  }
}

TerminalKey? terminalKeyForShortcutAction(ShortcutAction action) {
  switch (action) {
    case ShortcutAction.arrowUp:
      return TerminalKey.arrowUp;
    case ShortcutAction.arrowDown:
      return TerminalKey.arrowDown;
    case ShortcutAction.arrowLeft:
      return TerminalKey.arrowLeft;
    case ShortcutAction.arrowRight:
      return TerminalKey.arrowRight;
    case ShortcutAction.home:
      return TerminalKey.home;
    case ShortcutAction.end:
      return TerminalKey.end;
    case ShortcutAction.escapeKey:
      return TerminalKey.escape;
    case ShortcutAction.tabChar:
      return TerminalKey.tab;
    case ShortcutAction.newConnection:
    case ShortcutAction.profiles:
    case ShortcutAction.discovery:
    case ShortcutAction.keys:
    case ShortcutAction.ctrlA:
    case ShortcutAction.ctrlB:
    case ShortcutAction.ctrlC:
    case ShortcutAction.ctrlD:
    case ShortcutAction.ctrlE:
    case ShortcutAction.ctrlF:
    case ShortcutAction.ctrlG:
    case ShortcutAction.ctrlH:
    case ShortcutAction.ctrlJ:
    case ShortcutAction.ctrlK:
    case ShortcutAction.ctrlL:
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
    case ShortcutAction.ctrlZ:
    case ShortcutAction.ctrlV:
      return null;
  }
}

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

class _ShortcutChip extends StatefulWidget {
  final KeyboardShortcut shortcut;
  final bool isConnected;

  const _ShortcutChip({
    required this.shortcut,
    required this.isConnected,
  });

  @override
  State<_ShortcutChip> createState() => _ShortcutChipState();
}

class _ShortcutChipState extends State<_ShortcutChip> {
  Timer? _initialDelayTimer;
  Timer? _repeatTimer;
  bool _repeatActive = false;

  KeyboardShortcut get shortcut => widget.shortcut;
  bool get isConnected => widget.isConnected;

  bool get _supportsRepeat =>
      shortcutActionSupportsKeyRepeat(shortcut.action);

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  void _stopRepeat() {
    _initialDelayTimer?.cancel();
    _repeatTimer?.cancel();
    _initialDelayTimer = null;
    _repeatTimer = null;
    _repeatActive = false;
  }

  void _startRepeat(BuildContext context) {
    if (!isConnected || !_supportsRepeat) {
      return;
    }
    _stopRepeat();
    final ssh = context.read<SSHProvider>();
    final key = terminalKeyForShortcutAction(shortcut.action);
    if (key == null) {
      return;
    }
    final ctrl = ssh.pendingCtrl;
    final alt = ssh.pendingAlt;
    ssh.clearPendingModifiers();

    void fire() {
      ssh.sendTerminalKey(key, ctrl: ctrl, alt: alt);
    }

    _repeatActive = true;
    fire();
    _initialDelayTimer = Timer(kShortcutKeyRepeatInitialDelay, () {
      if (!_repeatActive) {
        return;
      }
      _repeatTimer = Timer.periodic(kShortcutKeyRepeatInterval, (_) {
        if (!_repeatActive) {
          return;
        }
        fire();
      });
    });
  }

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
        onTap: _supportsRepeat ? null : () => _handleTap(context),
        onTapDown: _supportsRepeat ? (_) => _startRepeat(context) : null,
        onTapUp: _supportsRepeat ? (_) => _stopRepeat() : null,
        onTapCancel: _supportsRepeat ? _stopRepeat : null,
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
      case ShortcutAction.arrowDown:
      case ShortcutAction.arrowRight:
      case ShortcutAction.arrowLeft:
        // Handled by hold-to-repeat via onTapDown.
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

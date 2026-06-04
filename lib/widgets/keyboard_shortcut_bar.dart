import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../models/keyboard_shortcut.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import 'connection_modal.dart';
import 'profile_manager.dart';
import 'network_discovery.dart';
import 'key_manager.dart';

class KeyboardShortcutBar extends StatelessWidget {
  final int? showRow;
  final bool forceShowOnMobile;

  const KeyboardShortcutBar(
      {super.key, this.showRow, this.forceShowOnMobile = false});

  @override
  Widget build(BuildContext context) {
    if (!forceShowOnMobile && (Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    return Consumer2<SettingsProvider, SSHProvider>(
      builder: (context, settings, ssh, child) {
        if (!settings.isLoaded) {
          return const SizedBox.shrink();
        }

        final maxRow = settings.maxRow;

        if (showRow != null) {
          final rowIndex = showRow! <= maxRow ? showRow! : maxRow;
          final shortcuts = settings.getShortcutsByRow(rowIndex);
          final active = ssh.activeSession;
          return _ShortcutRow(
            shortcuts: shortcuts,
            isConnected: active != null && active.isConnected,
          );
        }

        return Column(
          children: List.generate(maxRow + 1, (rowIndex) {
            final shortcuts = settings.getShortcutsByRow(rowIndex);
            return _ShortcutRow(
              shortcuts: shortcuts,
              isConnected: ssh.activeSession?.isConnected ?? false,
            );
          }),
        );
      },
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<KeyboardShortcut> shortcuts;
  final bool isConnected;

  const _ShortcutRow({
    required this.shortcuts,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 4, left: 0),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(0.25),
            border: Border.all(color: Colors.grey.shade600),
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
                    fontSize: 7,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  shortcut.description,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.grey.shade400,
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
          ssh.sendControlCharacter(shortcut.charCode!);
        }
        break;
      case ShortcutAction.ctrlC:
      case ShortcutAction.ctrlD:
      case ShortcutAction.ctrlZ:
      case ShortcutAction.ctrlL:
      case ShortcutAction.ctrlA:
      case ShortcutAction.ctrlP:
        if (isConnected && shortcut.charCode != null) {
          ssh.sendControlCharacter(shortcut.charCode!);
        }
        break;
      case ShortcutAction.arrowUp:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) active.terminal.keyInput(TerminalKey.arrowUp);
        }
        break;
      case ShortcutAction.arrowDown:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) active.terminal.keyInput(TerminalKey.arrowDown);
        }
        break;
      case ShortcutAction.arrowRight:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) active.terminal.keyInput(TerminalKey.arrowRight);
        }
        break;
      case ShortcutAction.arrowLeft:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) active.terminal.keyInput(TerminalKey.arrowLeft);
        }
        break;
      case ShortcutAction.home:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) {
            active.terminal.keyInput(TerminalKey.home);
          }
        }
        break;
      case ShortcutAction.end:
        if (isConnected) {
          final active = ssh.activeSession;
          if (active != null) {
            active.terminal.keyInput(TerminalKey.end);
          }
        }
        break;
    }
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

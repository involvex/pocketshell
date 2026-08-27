import 'package:flutter/material.dart';

/// Floating action button for scrolling chat messages.
class AgentScrollFab extends StatelessWidget {
  const AgentScrollFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.heroTag,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}

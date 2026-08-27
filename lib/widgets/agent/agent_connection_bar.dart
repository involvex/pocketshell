import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/agent_provider.dart';

/// Horizontal scrollable list of agent connection chips.
class AgentConnectionBar extends StatelessWidget {
  const AgentConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentProvider>(
      builder: (context, agents, child) {
        if (agents.connections.isEmpty) {
          return const SizedBox.shrink();
        }

        final chips = agents.connections.map((connection) {
          final isActive = agents.activeConnectionId == connection.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InputChip(
              selected: isActive,
              avatar: CircleAvatar(
                radius: 4,
                backgroundColor:
                    connection.isConnected ? Colors.green : Colors.red,
              ),
              label: Text(connection.profile.name),
              onPressed: () => agents.switchActiveConnection(connection.id),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => agents.disconnect(connection.id),
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        );
      },
    );
  }
}

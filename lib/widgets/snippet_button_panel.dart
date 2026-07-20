import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/snippet_provider.dart';
import '../screens/snippet_config_screen.dart';
import '../utils/terminal_enter_mapping.dart';

class SnippetButtonPanel extends StatefulWidget {
  const SnippetButtonPanel({super.key});

  @override
  State<SnippetButtonPanel> createState() => _SnippetButtonPanelState();
}

class _SnippetButtonPanelState extends State<SnippetButtonPanel> {
  bool _isExpanded = true;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SSHProvider, SnippetProvider>(
      builder: (context, ssh, snippets, child) {
        final active = ssh.activeSession;
        if (active == null || !active.isConnected || !snippets.isLoaded) {
          return const SizedBox.shrink();
        }

        final displaySnippets = snippets.snippets.take(5).toList();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(128),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: _toggleExpanded,
                    visualDensity: VisualDensity.compact,
                    tooltip: _isExpanded ? 'Hide snippets' : 'Show snippets',
                  ),
                  if (!_isExpanded)
                    const Text(
                      'Snippets',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (_isExpanded)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...displaySnippets.map((s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ActionChip(
                                    label: Text(
                                      s.name,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onPressed: () {
                                      final active = ssh.activeSession;
                                      if (active != null &&
                                          active.isConnected &&
                                          active.shellSession != null) {
                                        active.shellSession!.stdin.add(
                                          utf8.encode(
                                            withEnterSuffix(
                                              s.content,
                                              ssh.terminalEnterSends,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                )),
                            IconButton(
                              icon: const Icon(Icons.more_horiz, size: 20),
                              onPressed: () => _showSnippetSelection(context),
                              tooltip: 'More Snippets',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnippetSelection(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SnippetSelectionSheet(),
    );
  }
}

class _SnippetSelectionSheet extends StatelessWidget {
  const _SnippetSelectionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Snippet',
                      style: theme.textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const SnippetConfigScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Consumer2<SSHProvider, SnippetProvider>(
                  builder: (context, ssh, snippets, child) {
                    if (snippets.snippets.isEmpty) {
                      return const Center(child: Text('No snippets found.'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snippets.snippets.length,
                      itemBuilder: (context, index) {
                        final snippet = snippets.snippets[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.terminal,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(snippet.name),
                          subtitle: Text(
                            snippet.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            final active = ssh.activeSession;
                            if (active != null &&
                                active.isConnected &&
                                active.shellSession != null) {
                              active.shellSession!.stdin.add(
                                utf8.encode(
                                  withEnterSuffix(
                                    snippet.content,
                                    ssh.terminalEnterSends,
                                  ),
                                ),
                              );
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

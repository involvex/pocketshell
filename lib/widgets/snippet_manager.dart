import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../providers/ssh_provider.dart';

class SnippetManager extends StatelessWidget {
  const SnippetManager({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Text Snippets',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () => _showSnippetDialog(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<SnippetProvider>(
                  builder: (context, provider, child) {
                    if (!provider.isLoaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.snippets.isEmpty) {
                      return const Center(
                        child: Text('No snippets saved yet'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: provider.snippets.length,
                      itemBuilder: (context, index) {
                        final snippet = provider.snippets[index];
                        return ListTile(
                          leading: const Icon(Icons.code, color: Colors.blue),
                          title: Text(snippet.name),
                          subtitle: Text(snippet.content),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showSnippetDialog(context,
                                    snippet: snippet),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () =>
                                    provider.deleteSnippet(snippet.id),
                              ),
                            ],
                          ),
                          onTap: () => _useSnippet(context, snippet),
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

  void _showSnippetDialog(BuildContext context, {Snippet? snippet}) {
    final nameController = TextEditingController(text: snippet?.name ?? '');
    final contentController =
        TextEditingController(text: snippet?.content ?? '');
    final categoryController =
        TextEditingController(text: snippet?.category ?? 'General');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text(snippet == null ? 'Add Snippet' : 'Edit Snippet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Command'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    contentController.text.isEmpty) {
                  return;
                }
                final newSnippet = Snippet(
                  id: snippet?.id,
                  name: nameController.text,
                  content: contentController.text,
                  category: categoryController.text.isNotEmpty
                      ? categoryController.text
                      : 'General',
                );
                final provider =
                    Provider.of<SnippetProvider>(context, listen: false);
                if (snippet == null) {
                  provider.addSnippet(newSnippet);
                } else {
                  provider.updateSnippet(newSnippet);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _useSnippet(BuildContext context, Snippet snippet) {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final active = ssh.activeSession;
    if (active != null && active.isConnected && active.shellSession != null) {
      active.shellSession!.stdin.add(utf8.encode('${snippet.content}\r'));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to SSH server')),
      );
    }
  }
}

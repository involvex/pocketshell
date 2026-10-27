import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';

class SnippetConfigScreen extends StatefulWidget {
  const SnippetConfigScreen({super.key});

  @override
  State<SnippetConfigScreen> createState() => _SnippetConfigScreenState();
}

class _SnippetConfigScreenState extends State<SnippetConfigScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Snippets'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search snippets...',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<SnippetProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredSnippets = provider.snippets.where((s) {
            return s.name.toLowerCase().contains(_searchQuery) ||
                s.content.toLowerCase().contains(_searchQuery) ||
                s.category.toLowerCase().contains(_searchQuery);
          }).toList();

          if (filteredSnippets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.code_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No snippets yet'
                        : 'No matches found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_searchQuery.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: FilledButton.icon(
                        onPressed: () => _showSnippetDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Snippet'),
                      ),
                    ),
                ],
              ),
            );
          }

          final canReorder = _searchQuery.isEmpty;

          return Column(
            children: [
              if (!canReorder)
                Material(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Clear search to drag and reorder snippets',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: canReorder
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                        buildDefaultDragHandles: false,
                        itemCount: filteredSnippets.length,
                        onReorderItem: provider.reorderSnippets,
                        proxyDecorator: _snippetProxyDecorator,
                        itemBuilder: (context, index) {
                          return _SnippetTile(
                            key: ValueKey(filteredSnippets[index].id),
                            snippet: filteredSnippets[index],
                            index: index,
                            showDragHandle: true,
                            onEdit: () => _showSnippetDialog(
                              context,
                              snippet: filteredSnippets[index],
                            ),
                            onDelete: () => _confirmDelete(
                              context,
                              provider,
                              filteredSnippets[index],
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                        itemCount: filteredSnippets.length,
                        itemBuilder: (context, index) {
                          return _SnippetTile(
                            key: ValueKey(filteredSnippets[index].id),
                            snippet: filteredSnippets[index],
                            index: index,
                            showDragHandle: false,
                            onEdit: () => _showSnippetDialog(
                              context,
                              snippet: filteredSnippets[index],
                            ),
                            onDelete: () => _confirmDelete(
                              context,
                              provider,
                              filteredSnippets[index],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSnippetDialog(context),
        label: const Text('New Snippet'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _snippetProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
        return Material(
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Theme.of(context).colorScheme.shadow,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      child: child,
    );
  }

  void _confirmDelete(
      BuildContext context, SnippetProvider provider, Snippet snippet) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Snippet'),
        content: Text('Are you sure you want to delete "${snippet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSnippet(snippet.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnippetDialog(BuildContext context, {Snippet? snippet}) {
    final nameController = TextEditingController(text: snippet?.name ?? '');
    final contentController =
        TextEditingController(text: snippet?.content ?? '');
    final categoryController =
        TextEditingController(text: snippet?.category ?? 'General');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                snippet == null ? 'New Snippet' : 'Edit Snippet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., List Files',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'e.g., ls -la',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., File, Network, System',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
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
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnippetTile extends StatelessWidget {
  const _SnippetTile({
    required this.snippet,
    required this.index,
    required this.showDragHandle,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final Snippet snippet;
  final int index;
  final bool showDragHandle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: const Icon(Icons.terminal, size: 20),
        ),
        title: Text(
          snippet.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snippet.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                snippet.category,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
            if (showDragHandle)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

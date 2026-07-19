import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/providers/settings_provider.dart';

class ShortcutEditor extends StatefulWidget {
  const ShortcutEditor({super.key});

  @override
  State<ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<ShortcutEditor> {
  late List<KeyboardShortcut> _shortcuts;
  int _selectedRow = 0;
  VoidCallback? _settingsListener;
  late SettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _syncFromSettings(_settings);

    // Add listener to sync when settings finish loading
    if (!_settings.isLoaded) {
      _settingsListener = () {
        if (mounted) {
          setState(() {
            _syncFromSettings(_settings);
          });
        }
      };
      _settings.addListener(_settingsListener!);
    }
  }

  void _syncFromSettings(SettingsProvider settings) {
    _shortcuts = List.from(settings.shortcuts);
    _selectedRow = settings.maxRow >= 2 ? 2 : settings.maxRow;
  }

  @override
  void dispose() {
    if (_settingsListener != null) {
      _settings.removeListener(_settingsListener!);
    }
    super.dispose();
  }

  List<KeyboardShortcut> get _currentRowShortcuts {
    return _shortcuts.where((s) => s.row == _selectedRow).toList();
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final rowShortcuts = _currentRowShortcuts;
      final item = rowShortcuts.removeAt(oldIndex);
      rowShortcuts.insert(newIndex, item);

      // Reconstruct _shortcuts to reflect the new order within the row
      final otherRowShortcuts =
          _shortcuts.where((s) => s.row != _selectedRow).toList();
      _shortcuts = [...otherRowShortcuts, ...rowShortcuts];
    });
  }

  Future<void> _save() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    await settings.updateShortcuts(_shortcuts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shortcuts saved')),
    );
  }

  Future<void> _reset() async {
    final settings = context.read<SettingsProvider>();
    await settings.resetShortcuts();
    if (mounted) {
      setState(() {
        _shortcuts = List.from(settings.shortcuts);
      });
    }
  }

  Future<void> _addShortcut() async {
    final KeyboardShortcut? created = await _showShortcutDialog(
      title: 'Add Shortcut',
      initial: null,
    );
    if (created == null || !mounted) return;
    setState(() => _shortcuts.add(created));
  }

  Future<void> _editShortcut(KeyboardShortcut shortcut) async {
    final KeyboardShortcut? updated = await _showShortcutDialog(
      title: 'Edit Shortcut',
      initial: shortcut,
    );
    if (updated == null || !mounted) return;
    setState(() {
      final int idx = _shortcuts.indexWhere((s) => s.id == shortcut.id);
      if (idx >= 0) {
        _shortcuts[idx] = updated;
      }
    });
  }

  Future<KeyboardShortcut?> _showShortcutDialog({
    required String title,
    required KeyboardShortcut? initial,
  }) async {
    final List<ShortcutAction> actions =
        KeyboardShortcut.actionsForRow(_selectedRow);
    ShortcutAction selected = initial?.action ?? actions.first;
    final TextEditingController labelController = TextEditingController(
      text: initial?.label ?? KeyboardShortcut.defaultLabelFor(selected),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: initial?.description ??
          KeyboardShortcut.defaultDescriptionFor(selected),
    );

    final KeyboardShortcut? result = await showDialog<KeyboardShortcut>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<ShortcutAction>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: actions
                          .map(
                            (ShortcutAction a) => DropdownMenuItem(
                              value: a,
                              child: Text(KeyboardShortcut.displayNameFor(a)),
                            ),
                          )
                          .toList(),
                      onChanged: (ShortcutAction? value) {
                        if (value == null) return;
                        setDialogState(() {
                          selected = value;
                          labelController.text =
                              KeyboardShortcut.defaultLabelFor(value);
                          descriptionController.text =
                              KeyboardShortcut.defaultDescriptionFor(value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
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
                    final String label = labelController.text.trim();
                    final String description =
                        descriptionController.text.trim();
                    if (label.isEmpty || description.isEmpty) return;
                    Navigator.pop(
                      dialogContext,
                      KeyboardShortcut.createForAction(
                        selected,
                        row: _selectedRow,
                        id: initial?.id,
                        label: label,
                        description: description,
                      ),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
    descriptionController.dispose();
    return result;
  }

  void _removeShortcut(KeyboardShortcut shortcut) {
    setState(() {
      _shortcuts.removeWhere((s) => s.id == shortcut.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Configure Shortcuts',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Row: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('App')),
                    ButtonSegment(value: 1, label: Text('Terminal')),
                    ButtonSegment(value: 2, label: Text('Ctrl')),
                  ],
                  selected: {_selectedRow},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() => _selectedRow = newSelection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentRowShortcuts.length,
              onReorderItem: _onReorderItem,
              itemBuilder: (context, index) {
                final KeyboardShortcut shortcut = _currentRowShortcuts[index];
                return _ShortcutTile(
                  key: ValueKey<String>(shortcut.id),
                  index: index,
                  shortcut: shortcut,
                  onDelete: () => _removeShortcut(shortcut),
                  onEdit: () => _editShortcut(shortcut),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _addShortcut,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final int index;
  final KeyboardShortcut shortcut;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ShortcutTile({
    required this.index,
    required this.shortcut,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(shortcut.label),
        subtitle: Text(shortcut.description),
        onTap: onEdit,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

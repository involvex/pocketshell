import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keyboard_shortcut.dart';
import '../providers/settings_provider.dart';

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
    final settings = context.read<SettingsProvider>();
    await settings.updateShortcuts(_shortcuts);
    if (mounted) Navigator.pop(context);
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

  void _addShortcut() {
    final newShortcut = KeyboardShortcut(
      label: 'New',
      description: 'New Shortcut',
      action: ShortcutAction.newConnection,
      row: _selectedRow,
    );
    setState(() {
      _shortcuts.add(newShortcut);
    });
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
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16),
        child: Column(
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
            Expanded(
              child: ReorderableListView.builder(
              itemCount: _currentRowShortcuts.length,
              onReorderItem: _onReorderItem,
                itemBuilder: (context, index) {
                  final shortcut = _currentRowShortcuts[index];
                  return _ShortcutTile(
                    key: ValueKey(shortcut.id),
                    shortcut: shortcut,
                    onDelete: () => _removeShortcut(shortcut),
                    onLabelChanged: (label) {
                      setState(() {
                        final idx =
                            _shortcuts.indexWhere((s) => s.id == shortcut.id);
                        if (idx >= 0) {
                          _shortcuts[idx] = shortcut.copyWith(label: label);
                        }
                      });
                    },
                  );
                },
              ),
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
  final KeyboardShortcut shortcut;
  final VoidCallback onDelete;
  final ValueChanged<String> onLabelChanged;

  const _ShortcutTile({
    required this.shortcut, required this.onDelete, required this.onLabelChanged, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(shortcut.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.drag_handle),
        title: Text(shortcut.label),
        subtitle: Text(shortcut.description),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ssh_app/utils/remote_fs_sort.dart';

/// Shared header for SFTP browser-style surfaces.
class SftpBrowserHeader extends StatefulWidget {
  const SftpBrowserHeader({
    required this.currentPath,
    required this.filterTerm,
    required this.sortField,
    required this.sortAscending,
    required this.onCopyPath,
    required this.onDriveSelected,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onRefresh,
    this.drives = const <String>[],
    this.onCreateDirectory,
    this.onUpload,
    super.key,
  });

  final String currentPath;
  final List<String> drives;
  final String filterTerm;
  final RemoteFsSortField sortField;
  final bool sortAscending;
  final Future<void> Function() onCopyPath;
  final Future<void> Function(String drive) onDriveSelected;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(RemoteFsSortField field, bool ascending)
      onSortChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String name)? onCreateDirectory;
  final Future<void> Function()? onUpload;

  @override
  State<SftpBrowserHeader> createState() => _SftpBrowserHeaderState();
}

class _SftpBrowserHeaderState extends State<SftpBrowserHeader> {
  late final TextEditingController _searchController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filterTerm);
    _showSearch = widget.filterTerm.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant SftpBrowserHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.filterTerm) {
      _searchController.value = TextEditingValue(
        text: widget.filterTerm,
        selection: TextSelection.collapsed(offset: widget.filterTerm.length),
      );
    }
    if (!_showSearch && widget.filterTerm.trim().isNotEmpty) {
      _showSearch = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.currentPath));
    await widget.onCopyPath();
  }

  Future<void> _promptForDirectory() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || name == null || name.trim().isEmpty) {
      return;
    }
    await widget.onCreateDirectory?.call(name.trim());
  }

  Future<void> _handleSortAction(_SortAction action) {
    switch (action) {
      case _SortAction.name:
        return widget.onSortChanged(
            RemoteFsSortField.name, widget.sortAscending);
      case _SortAction.date:
        return widget.onSortChanged(
            RemoteFsSortField.date, widget.sortAscending);
      case _SortAction.size:
        return widget.onSortChanged(
            RemoteFsSortField.size, widget.sortAscending);
      case _SortAction.type:
        return widget.onSortChanged(
            RemoteFsSortField.type, widget.sortAscending);
      case _SortAction.ascending:
        return widget.onSortChanged(widget.sortField, true);
      case _SortAction.descending:
        return widget.onSortChanged(widget.sortField, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String selectedDrive = widget.drives.firstWhere(
      (String drive) => widget.currentPath.startsWith('$drive:'),
      orElse: () => '',
    );
    final bool hasDriveSelection = widget.drives.isNotEmpty;
    final bool showSecondaryRow = hasDriveSelection || _showSearch;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Remote files',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.currentPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy path',
                  onPressed: () async {
                    await _copyPath();
                  },
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: _showSearch ? 'Hide search' : 'Search',
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch && _searchController.text.isNotEmpty) {
                        _searchController.clear();
                        widget.onFilterChanged('');
                      }
                    });
                  },
                  icon: Icon(
                    _showSearch ? Icons.search_off_outlined : Icons.search,
                  ),
                ),
                PopupMenuButton<_SortAction>(
                  tooltip: 'Sort',
                  onSelected: (_SortAction action) async {
                    await _handleSortAction(action);
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_SortAction>>[
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.name,
                      child: Text('Sort by name'),
                    ),
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.date,
                      child: Text('Sort by date'),
                    ),
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.size,
                      child: Text('Sort by size'),
                    ),
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.type,
                      child: Text('Sort by type'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.ascending,
                      child: Text('Ascending'),
                    ),
                    const PopupMenuItem<_SortAction>(
                      value: _SortAction.descending,
                      child: Text('Descending'),
                    ),
                  ],
                  icon: const Icon(Icons.sort),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () async {
                    await widget.onRefresh();
                  },
                  icon: const Icon(Icons.refresh),
                ),
                if (widget.onCreateDirectory != null)
                  IconButton(
                    tooltip: 'New folder',
                    onPressed: _promptForDirectory,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                if (widget.onUpload != null)
                  IconButton(
                    tooltip: 'Upload',
                    onPressed: () async {
                      await widget.onUpload?.call();
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                  ),
              ],
            ),
            if (showSecondaryRow) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (hasDriveSelection)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            selectedDrive.isEmpty ? null : selectedDrive,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Drive',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: widget.drives
                            .map(
                              (String drive) => DropdownMenuItem<String>(
                                value: drive,
                                child: Text('$drive:/'),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          widget.onDriveSelected(value);
                        },
                      ),
                    ),
                  if (hasDriveSelection && _showSearch)
                    const SizedBox(width: 12),
                  if (_showSearch)
                    Expanded(
                      flex: hasDriveSelection ? 2 : 1,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (String value) {
                          widget.onFilterChanged(value);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Search',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    widget.onFilterChanged('');
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SortAction { name, date, size, type, ascending, descending }

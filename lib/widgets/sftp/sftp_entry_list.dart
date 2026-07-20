import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';
import 'package:ssh_app/widgets/sftp/sftp_image_preview.dart';
import 'package:ssh_app/widgets/sftp/sftp_text_preview.dart';

/// Shared SFTP entry list with directory-only and file-browser modes.
class SftpEntryList extends StatelessWidget {
  const SftpEntryList({
    required this.entries,
    required this.currentPath,
    required this.loading,
    required this.onOpenEntry,
    this.error,
    this.directoriesOnly = false,
    this.selectionMode = false,
    this.selectedNames = const <String>{},
    this.onToggleSelected,
    this.onDownloadEntry,
    this.onEditEntry,
    this.onPreviewEntry,
    this.onRenameEntry,
    this.onDeleteEntry,
    this.onCopyEntry,
    this.onMoveEntry,
    super.key,
  });

  final List<RemoteFsEntry> entries;
  final String currentPath;
  final bool loading;
  final String? error;
  final bool directoriesOnly;
  final bool selectionMode;
  final Set<String> selectedNames;
  final Future<void> Function(RemoteFsEntry entry) onOpenEntry;
  final void Function(RemoteFsEntry entry)? onToggleSelected;
  final Future<void> Function(RemoteFsEntry entry)? onDownloadEntry;
  final Future<void> Function(RemoteFsEntry entry)? onEditEntry;
  final Future<void> Function(RemoteFsEntry entry)? onPreviewEntry;
  final Future<void> Function(RemoteFsEntry entry, String newName)?
      onRenameEntry;
  final Future<void> Function(RemoteFsEntry entry)? onDeleteEntry;
  final Future<void> Function(RemoteFsEntry entry)? onCopyEntry;
  final Future<void> Function(RemoteFsEntry entry)? onMoveEntry;

  @override
  Widget build(BuildContext context) {
    final List<RemoteFsEntry> visibleEntries = directoriesOnly
        ? entries
            .where(
              (RemoteFsEntry entry) => entry.isDirectory || entry.isParentLink,
            )
            .toList()
        : entries;

    if (loading && visibleEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && visibleEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load directory.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (visibleEntries.isEmpty) {
      return const Center(child: Text('No entries found'));
    }

    return Column(
      children: <Widget>[
        if (error != null)
          MaterialBanner(
            content: Text('Failed to refresh: $error'),
            actions: const <Widget>[SizedBox.shrink()],
          ),
        Expanded(
          child: Stack(
            children: <Widget>[
              ListView.builder(
                itemCount: visibleEntries.length,
                itemBuilder: (BuildContext context, int index) {
                  final RemoteFsEntry entry = visibleEntries[index];
                  return _EntryTile(
                    entry: entry,
                    currentPath: currentPath,
                    directoriesOnly: directoriesOnly,
                    selectionMode: selectionMode,
                    selected: selectedNames.contains(entry.name),
                    onOpenEntry: onOpenEntry,
                    onToggleSelected: onToggleSelected,
                    onDownloadEntry: onDownloadEntry,
                    onEditEntry: onEditEntry,
                    onPreviewEntry: onPreviewEntry,
                    onRenameEntry: onRenameEntry,
                    onDeleteEntry: onDeleteEntry,
                    onCopyEntry: onCopyEntry,
                    onMoveEntry: onMoveEntry,
                  );
                },
              ),
              if (loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.currentPath,
    required this.directoriesOnly,
    required this.onOpenEntry,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onDownloadEntry,
    this.onEditEntry,
    this.onPreviewEntry,
    this.onRenameEntry,
    this.onDeleteEntry,
    this.onCopyEntry,
    this.onMoveEntry,
  });

  final RemoteFsEntry entry;
  final String currentPath;
  final bool directoriesOnly;
  final bool selectionMode;
  final bool selected;
  final Future<void> Function(RemoteFsEntry entry) onOpenEntry;
  final void Function(RemoteFsEntry entry)? onToggleSelected;
  final Future<void> Function(RemoteFsEntry entry)? onDownloadEntry;
  final Future<void> Function(RemoteFsEntry entry)? onEditEntry;
  final Future<void> Function(RemoteFsEntry entry)? onPreviewEntry;
  final Future<void> Function(RemoteFsEntry entry, String newName)?
      onRenameEntry;
  final Future<void> Function(RemoteFsEntry entry)? onDeleteEntry;
  final Future<void> Function(RemoteFsEntry entry)? onCopyEntry;
  final Future<void> Function(RemoteFsEntry entry)? onMoveEntry;

  @override
  Widget build(BuildContext context) {
    final bool canShowMenu = !entry.isParentLink;
    final bool canDownload =
        !directoriesOnly && !entry.isDirectory && onDownloadEntry != null;

    return ListTile(
      selected: selected,
      leading: selectionMode && !entry.isParentLink
          ? Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelected?.call(entry),
            )
          : Icon(
              entry.isParentLink
                  ? Icons.arrow_upward
                  : entry.isDirectory
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
            ),
      title: Text(entry.name),
      subtitle: Text(_buildSubtitle(entry)),
      onTap: () async {
        if (selectionMode && !entry.isParentLink) {
          onToggleSelected?.call(entry);
          return;
        }
        if (entry.isDirectory) {
          await onOpenEntry(entry);
        }
      },
      onLongPress: canShowMenu
          ? () async {
              if (!directoriesOnly && onToggleSelected != null) {
                onToggleSelected!(entry);
                return;
              }
              await _showEntryActions(context);
            }
          : null,
      trailing: canShowMenu && !selectionMode
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (canDownload)
                  IconButton(
                    tooltip: 'Download',
                    onPressed: () async {
                      await onDownloadEntry?.call(entry);
                    },
                    icon: const Icon(Icons.download_outlined),
                  ),
                IconButton(
                  tooltip: 'More actions',
                  onPressed: () async {
                    await _showEntryActions(context);
                  },
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showEntryActions(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String fullPath = RemotePath.join(currentPath, entry.name);
    final bool canEdit = !entry.isDirectory &&
        !directoriesOnly &&
        onEditEntry != null &&
        isSftpTextPreviewExtension(entry.name);
    final bool canPreview = !entry.isDirectory &&
        !directoriesOnly &&
        onPreviewEntry != null &&
        isSftpImagePreviewExtension(entry.name);

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text('Copy path'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: fullPath));
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Path copied')),
                  );
                },
              ),
              if (!entry.isDirectory &&
                  !directoriesOnly &&
                  onDownloadEntry != null)
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onDownloadEntry?.call(entry);
                  },
                ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onEditEntry?.call(entry);
                  },
                ),
              if (canPreview)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Preview'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onPreviewEntry?.call(entry);
                  },
                ),
              if (onRenameEntry != null)
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final String? newName = await _promptForRename(context);
                    if (newName == null || newName.isEmpty) {
                      return;
                    }
                    await onRenameEntry?.call(entry, newName);
                  },
                ),
              if (onCopyEntry != null && !entry.isDirectory)
                ListTile(
                  leading: const Icon(Icons.file_copy_outlined),
                  title: const Text('Copy to…'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onCopyEntry?.call(entry);
                  },
                ),
              if (onMoveEntry != null)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Move to…'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onMoveEntry?.call(entry);
                  },
                ),
              if (onDeleteEntry != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final bool confirmed =
                        await _confirmDelete(context) ?? false;
                    if (!confirmed) {
                      return;
                    }
                    await onDeleteEntry?.call(entry);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _promptForRename(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: entry.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New name',
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
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim();
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete entry'),
          content: Text('Delete "${entry.name}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

String _buildSubtitle(RemoteFsEntry entry) {
  if (entry.isParentLink) {
    return 'Parent directory';
  }

  final List<String> details = <String>[
    entry.isDirectory ? 'Folder' : _formatBytes(entry.size),
  ];
  if (entry.modifyTime != null) {
    details.add(_formatModifyTime(entry.modifyTime!));
  }
  return details.join('  •  ');
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return 'Unknown size';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  for (final String unit in units) {
    if (value < 1024 || unit == units.last) {
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} $unit';
    }
    value /= 1024;
  }
  return '$bytes B';
}

String _formatModifyTime(int secondsSinceEpoch) {
  final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch * 1000,
  ).toLocal();
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');
  final String hour = dateTime.hour.toString().padLeft(2, '0');
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute';
}

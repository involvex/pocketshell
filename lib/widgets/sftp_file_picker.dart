import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/providers/sftp_controller.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';

/// SFTP browser dialog that returns the selected remote file path.
class SftpFilePicker extends StatefulWidget {
  const SftpFilePicker({
    required this.client,
    this.initialPath,
    super.key,
  });

  final SSHClient client;
  final String? initialPath;

  @override
  State<SftpFilePicker> createState() => _SftpFilePickerState();
}

class _SftpFilePickerState extends State<SftpFilePicker> {
  late final SftpController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SftpController(client: widget.client);
    unawaited(_controller.init(initialPath: widget.initialPath));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectFile(String path) {
    Navigator.pop(context, path);
  }

  Future<void> _openEntry(RemoteFsEntry entry) async {
    if (entry.isDirectory) {
      await _controller.openEntry(entry);
      return;
    }
    if (entry.isParentLink) {
      await _controller.openEntry(entry);
      return;
    }
    final path = RemotePath.join(_controller.currentPath, entry.name);
    _selectFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screen.width - 24,
        height: screen.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Select file',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return SftpBrowserHeader(
                  currentPath: _controller.currentPath,
                  drives: _controller.drives,
                  filterTerm: _controller.filterTerm,
                  sortField: _controller.sortField,
                  sortAscending: _controller.sortAscending,
                  showSectionTitle: false,
                  onCopyPath: () async {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied')),
                    );
                  },
                  onDriveSelected: (String drive) =>
                      _controller.navigateTo('$drive:/'),
                  onFilterChanged: _controller.setFilter,
                  onSortChanged: (RemoteFsSortField field, bool ascending) =>
                      _controller.setSort(field, ascending: ascending),
                  onRefresh: _controller.refresh,
                  onCreateDirectory: _controller.mkdir,
                );
              },
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  return SftpEntryList(
                    entries: _controller.visibleEntries,
                    currentPath: _controller.currentPath,
                    loading: _controller.loading,
                    error: _controller.error,
                    directoriesOnly: false,
                    listBottomPadding: 8,
                    onOpenEntry: _openEntry,
                    onRenameEntry: _controller.rename,
                    onDeleteEntry: _controller.deleteEntry,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Tap a file to attach its remote path.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
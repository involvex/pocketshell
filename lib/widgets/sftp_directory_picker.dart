import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import 'package:ssh_app/providers/sftp_controller.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';

/// SFTP browser dialog that returns the selected remote directory path.
class SftpDirectoryPicker extends StatefulWidget {
  const SftpDirectoryPicker({
    required this.client,
    this.initialPath,
    super.key,
  });

  final SSHClient client;
  final String? initialPath;

  @override
  State<SftpDirectoryPicker> createState() => _SftpDirectoryPickerState();
}

class _SftpDirectoryPickerState extends State<SftpDirectoryPicker> {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Project Directory'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SftpBrowserHeader(
                  currentPath: _controller.currentPath,
                  drives: _controller.drives,
                  filterTerm: _controller.filterTerm,
                  sortField: _controller.sortField,
                  sortAscending: _controller.sortAscending,
                  onCopyPath: () async {
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied')),
                    );
                  },
                  onDriveSelected: (String drive) =>
                      _controller.navigateTo('$drive:/'),
                  onFilterChanged: _controller.setFilter,
                  onSortChanged: (
                    RemoteFsSortField field,
                    bool ascending,
                  ) =>
                      _controller.setSort(field, ascending: ascending),
                  onRefresh: _controller.refresh,
                  onCreateDirectory: _controller.mkdir,
                ),
                Expanded(
                  child: SftpEntryList(
                    entries: _controller.visibleEntries,
                    currentPath: _controller.currentPath,
                    loading: _controller.loading,
                    error: _controller.error,
                    directoriesOnly: true,
                    onOpenEntry: _controller.openEntry,
                    onRenameEntry: _controller.rename,
                    onDeleteEntry: _controller.deleteEntry,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.currentPath),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

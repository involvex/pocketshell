import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import 'package:ssh_app/providers/sftp_controller.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';

/// Layout shell for directory picker surfaces (testable without SSH).
class SftpDirectoryPickerShell extends StatelessWidget {
  const SftpDirectoryPickerShell({
    required this.header,
    required this.body,
    required this.onCancel,
    required this.onSelect,
    super.key,
  });

  final Widget header;
  final Widget body;
  final VoidCallback onCancel;
  final VoidCallback onSelect;

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
                      'Select Project Directory',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            header,
            Expanded(child: body),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onSelect,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return SftpDirectoryPickerShell(
      onCancel: () => Navigator.pop(context),
      onSelect: () => Navigator.pop(context, _controller.currentPath),
      header: AnimatedBuilder(
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
            onSortChanged: (RemoteFsSortField field, bool ascending) =>
                _controller.setSort(field, ascending: ascending),
            onRefresh: _controller.refresh,
            onCreateDirectory: _controller.mkdir,
          );
        },
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return SftpEntryList(
            entries: _controller.visibleEntries,
            currentPath: _controller.currentPath,
            loading: _controller.loading,
            error: _controller.error,
            directoriesOnly: true,
            listBottomPadding: 8,
            onOpenEntry: _controller.openEntry,
            onRenameEntry: _controller.rename,
            onDeleteEntry: _controller.deleteEntry,
          );
        },
      ),
    );
  }
}

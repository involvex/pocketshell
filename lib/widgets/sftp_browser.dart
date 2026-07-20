// lib/widgets/sftp_browser.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/providers/sftp_controller.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';
import 'package:ssh_app/widgets/sftp/sftp_image_preview.dart';
import 'package:ssh_app/widgets/sftp/sftp_text_preview.dart';
import 'package:ssh_app/widgets/sftp/sftp_transfer_banner.dart';

class SftpBrowser extends StatefulWidget {
  final String sessionId;
  const SftpBrowser({required this.sessionId, super.key});

  @override
  State<SftpBrowser> createState() => _SftpBrowserState();
}

class _SftpBrowserState extends State<SftpBrowser> {
  SftpController? _controller;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    final SSHProvider provider =
        Provider.of<SSHProvider>(context, listen: false);
    final matches =
        provider.sessions.where((session) => session.id == widget.sessionId);
    final session = matches.isEmpty ? null : matches.first;
    final client = session?.client;

    if (client == null) {
      _sessionError = 'Connect to the SSH session before opening SFTP.';
      return;
    }

    _controller = SftpController(client: client);
    unawaited(_controller!.init());
  }

  Future<void> _showCopiedSnackbar() async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Path copied')),
    );
  }

  void _showOperationSnackBar({
    required SftpController controller,
    required bool success,
    required String successMessage,
  }) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      return;
    }
    final String? error = controller.error;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _createDirectory(String name) async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.mkdir(name);
  }

  Future<void> _upload() async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }

    // pickFiles defaults to multi-select in file_picker 12+.
    final FilePickerResult? result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) {
      return;
    }

    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
    if (files.isEmpty) {
      return;
    }

    final int completed = await controller.uploadMany(files);
    _showOperationSnackBar(
      controller: controller,
      success: completed > 0 && controller.error == null,
      successMessage: completed == 1
          ? 'Uploaded'
          : 'Uploaded $completed file(s)',
    );
  }

  Future<void> _uploadDirectory() async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }

    final String? pickedDirectory = await FilePicker.getDirectoryPath();
    if (pickedDirectory == null) {
      return;
    }

    final int completed =
        await controller.uploadDirectory(Directory(pickedDirectory));
    _showOperationSnackBar(
      controller: controller,
      success: completed > 0 && controller.error == null,
      successMessage: completed == 1
          ? 'Uploaded folder (1 file)'
          : 'Uploaded folder ($completed files)',
    );
  }

  Future<void> _downloadSelected() async {
    final SftpController? controller = _controller;
    if (controller == null || controller.selectedNames.isEmpty) {
      return;
    }
    final String? pickedDirectory = await FilePicker.getDirectoryPath();
    if (pickedDirectory == null) {
      return;
    }
    final int completed =
        await controller.downloadSelected(Directory(pickedDirectory));
    _showOperationSnackBar(
      controller: controller,
      success: completed > 0 && controller.error == null,
      successMessage: 'Downloaded $completed item(s)',
    );
  }

  Future<String?> _promptDestinationDir(String title) async {
    final textController = TextEditingController(
      text: _controller?.currentPath ?? '/',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Destination directory',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, textController.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    textController.dispose();
    return result;
  }

  Future<void> _copyEntry(RemoteFsEntry entry) async {
    final c = _controller;
    if (c == null) return;
    final dest = await _promptDestinationDir('Copy to directory');
    if (dest == null || dest.isEmpty) return;
    final ok = await c.copyEntry(entry, dest);
    _showOperationSnackBar(
      controller: c,
      success: ok,
      successMessage: 'Copied',
    );
  }

  Future<void> _moveEntry(RemoteFsEntry entry) async {
    final c = _controller;
    if (c == null) return;
    final dest = await _promptDestinationDir('Move to directory');
    if (dest == null || dest.isEmpty) return;
    final ok = await c.moveEntry(entry, dest);
    _showOperationSnackBar(
      controller: c,
      success: ok,
      successMessage: 'Moved',
    );
  }

  Future<void> _download(RemoteFsEntry entry) async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }

    final String? pickedDirectory = await FilePicker.getDirectoryPath();
    if (pickedDirectory == null) {
      return;
    }

    final Directory localDirectory = Directory(pickedDirectory);
    final String localPath = controller.localDownloadPath(
      localDirectory,
      entry.name,
    );
    final bool localExists = entry.isDirectory
        ? await Directory(localPath).exists()
        : await File(localPath).exists();
    if (localExists &&
        !await _confirmOverwrite(
          title: entry.isDirectory
              ? 'Overwrite local folder?'
              : 'Overwrite local file?',
          message: entry.isDirectory
              ? 'A folder named "${entry.name}" already exists in this '
                  'location. Existing files with the same names may be '
                  'replaced. Continue?'
              : 'A file named "${entry.name}" already exists in this folder. '
                  'Do you want to replace it?',
        )) {
      return;
    }

    final bool success = await controller.download(entry, localDirectory);
    _showOperationSnackBar(
      controller: controller,
      success: success,
      successMessage: 'Downloaded',
    );
  }

  Future<bool> _confirmOverwrite({
    required String title,
    required String message,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _editEntry(RemoteFsEntry entry) async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (!isSftpTextPreviewExtension(entry.name)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file cannot be edited here.')),
      );
      return;
    }
    await showSftpTextPreviewDialog(
      context: context,
      fileName: entry.name,
      onLoad: () => controller.readRemoteBytes(
        entry,
        maxBytes: kSftpPreviewMaxBytes,
      ),
      onSave: (Uint8List data) => controller.writeRemoteBytes(entry, data),
    );
  }

  Future<void> _previewEntry(RemoteFsEntry entry) async {
    final SftpController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (!isSftpImagePreviewExtension(entry.name)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file cannot be previewed here.')),
      );
      return;
    }
    await showSftpImagePreviewDialog(
      context: context,
      fileName: entry.name,
      onLoad: () => controller.readRemoteBytes(
        entry,
        maxBytes: kSftpPreviewMaxBytes,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SftpController? controller = _controller;

    if (controller == null) {
      return Material(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _sessionError ?? 'SFTP is unavailable for this session.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            children: <Widget>[
              SftpBrowserHeader(
                currentPath: controller.currentPath,
                drives: controller.drives,
                filterTerm: controller.filterTerm,
                sortField: controller.sortField,
                sortAscending: controller.sortAscending,
                onCopyPath: _showCopiedSnackbar,
                onDriveSelected: (String drive) =>
                    controller.navigateTo('$drive:/'),
                onFilterChanged: controller.setFilter,
                onSortChanged: (
                  RemoteFsSortField field,
                  bool ascending,
                ) =>
                    controller.setSort(field, ascending: ascending),
                onRefresh: controller.refresh,
                onCreateDirectory: _createDirectory,
                onUpload: _upload,
                onUploadDirectory: _uploadDirectory,
              ),
              if (controller.selectionMode)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text('${controller.selectedNames.length} selected'),
                        const Spacer(),
                        TextButton(
                          onPressed: _downloadSelected,
                          child: const Text('Download'),
                        ),
                        TextButton(
                          onPressed: controller.clearSelection,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (controller.transferLabel != null)
                SftpTransferBanner(
                  label: controller.transferLabel!,
                  transferredBytes: controller.transferBytes,
                  totalBytes: controller.transferTotal,
                  onCancel: controller.cancelTransfer,
                ),
              Expanded(
                child: SftpEntryList(
                  entries: controller.visibleEntries,
                  currentPath: controller.currentPath,
                  loading: controller.loading,
                  error: controller.error,
                  selectionMode: controller.selectionMode,
                  selectedNames: controller.selectedNames,
                  onToggleSelected: controller.toggleSelected,
                  onOpenEntry: controller.openEntry,
                  onDownloadEntry: _download,
                  onEditEntry: _editEntry,
                  onPreviewEntry: _previewEntry,
                  onRenameEntry: controller.rename,
                  onDeleteEntry: controller.deleteEntry,
                  onCopyEntry: _copyEntry,
                  onMoveEntry: _moveEntry,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

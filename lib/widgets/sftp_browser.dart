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

    final FilePickerResult? result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) {
      return;
    }

    final bool success =
        await controller.upload(File(result.files.single.path!));
    _showOperationSnackBar(
      controller: controller,
      success: success,
      successMessage: 'Uploaded',
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

    final bool success =
        await controller.download(entry, Directory(pickedDirectory));
    _showOperationSnackBar(
      controller: controller,
      success: success,
      successMessage: 'Downloaded',
    );
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
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
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
                    onOpenEntry: controller.openEntry,
                    onDownloadEntry: _download,
                    onEditEntry: _editEntry,
                    onPreviewEntry: _previewEntry,
                    onRenameEntry: controller.rename,
                    onDeleteEntry: controller.deleteEntry,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';

/// Session-scoped SFTP explorer state and file operations.
class SftpController extends ChangeNotifier {
  SftpController({required SSHClient client}) : _helper = SftpHelper(client);

  final SftpHelper _helper;

  String currentPath = '/';
  List<RemoteFsEntry> _raw = <RemoteFsEntry>[];
  List<String> drives = <String>[];
  bool loading = false;
  String? error;
  String filterTerm = '';
  RemoteFsSortField sortField = RemoteFsSortField.name;
  bool sortAscending = true;

  int? transferBytes;
  int? transferTotal;
  String? transferLabel;
  SftpCancelToken? _cancel;

  List<RemoteFsEntry> get visibleEntries {
    final entries = applyRemoteFsView(
      _raw,
      filter: filterTerm,
      field: sortField,
      ascending: sortAscending,
    );
    if (RemotePath.isRoot(currentPath)) {
      return entries;
    }
    return <RemoteFsEntry>[
      const RemoteFsEntry(name: '..', isDirectory: true),
      ...entries,
    ];
  }

  Future<void> init({String? initialPath}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final savedSortField = await ConfigService.getSftpSortField();
      sortField = RemoteFsSortField.values.firstWhere(
        (field) => field.name == savedSortField,
        orElse: () => RemoteFsSortField.name,
      );
      sortAscending = await ConfigService.getSftpSortAscending();
      drives = await _helper.listDrives();

      final savedPath = initialPath ?? await ConfigService.getSftpLastPath();
      if (savedPath != null && savedPath.isNotEmpty) {
        currentPath = RemotePath.normalize(savedPath);
      } else if (drives.isNotEmpty) {
        currentPath = '${drives.first}:/';
      } else {
        currentPath = '/';
      }
    } catch (e) {
      error = e.toString();
      drives = <String>[];
      currentPath = '/';
      _raw = <RemoteFsEntry>[];
    } finally {
      loading = false;
      notifyListeners();
    }

    if (error == null) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      _raw = await _helper.listDir(currentPath);
      await ConfigService.saveSftpLastPath(currentPath);
    } catch (e) {
      error = e.toString();
      _raw = <RemoteFsEntry>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> navigateTo(String path) async {
    currentPath = RemotePath.normalize(path);
    filterTerm = '';
    await refresh();
  }

  Future<void> openEntry(RemoteFsEntry entry) async {
    if (!entry.isDirectory) {
      return;
    }
    if (entry.isParentLink) {
      await navigateTo(RemotePath.parent(currentPath));
      return;
    }
    await navigateTo(RemotePath.join(currentPath, entry.name));
  }

  void setFilter(String value) {
    filterTerm = value;
    notifyListeners();
  }

  Future<void> setSort(RemoteFsSortField field, {bool? ascending}) async {
    sortField = field;
    if (ascending != null) {
      sortAscending = ascending;
    }
    await ConfigService.saveSftpSortField(field.name);
    await ConfigService.saveSftpSortAscending(sortAscending);
    notifyListeners();
  }

  Future<bool> mkdir(String name) async {
    final entryName = name.trim();
    if (entryName.isEmpty) {
      return false;
    }
    return _runMutation(() async {
      await _helper.mkdir(RemotePath.join(currentPath, entryName));
    });
  }

  Future<bool> rename(RemoteFsEntry entry, String newName) async {
    if (entry.isParentLink) {
      return false;
    }

    final targetName = newName.trim();
    if (targetName.isEmpty || targetName == entry.name) {
      return false;
    }

    return _runMutation(() async {
      final fromPath = RemotePath.join(currentPath, entry.name);
      final toPath = RemotePath.join(currentPath, targetName);
      await _helper.rename(fromPath, toPath);
    });
  }

  Future<bool> deleteEntry(RemoteFsEntry entry) async {
    if (entry.isParentLink) {
      return false;
    }

    return _runMutation(() async {
      final path = RemotePath.join(currentPath, entry.name);
      if (entry.isDirectory) {
        await _helper.removeDir(path);
      } else {
        await _helper.removeFile(path);
      }
    });
  }

  Future<bool> upload(File localFile, {String? remoteName}) async {
    final filename = (remoteName ?? _fileNameFor(localFile)).trim();
    if (filename.isEmpty) {
      return false;
    }

    final remotePath = RemotePath.join(currentPath, filename);

    return _runMutation(() async {
      final totalBytes = await localFile.length();
      _startTransfer(
        label: 'Uploading $filename',
        totalBytes: totalBytes,
      );
      await _helper.upload(
        localFile,
        remotePath,
        onProgress: (bytesTransferred, knownTotalBytes) {
          _updateTransferProgress(bytesTransferred, knownTotalBytes);
        },
        cancelToken: _cancel,
      );
    });
  }

  Future<bool> download(
    RemoteFsEntry entry,
    Directory localDirectory, {
    String? localName,
  }) async {
    if (entry.isDirectory || entry.isParentLink) {
      return false;
    }

    final filename = (localName ?? entry.name).trim();
    if (filename.isEmpty) {
      return false;
    }

    final remotePath = RemotePath.join(currentPath, entry.name);
    final localPath = _joinLocalPath(localDirectory.path, filename);
    final localFile = File(localPath);

    return _runMutation(() async {
      _startTransfer(
        label: 'Downloading ${entry.name}',
        totalBytes: entry.size,
      );
      await _helper.downloadStream(
        remotePath,
        localFile,
        knownSize: entry.size,
        onProgress: (bytesTransferred, knownTotalBytes) {
          _updateTransferProgress(bytesTransferred, knownTotalBytes);
        },
        cancelToken: _cancel,
      );
    }, refreshAfter: false);
  }

  void cancelTransfer() {
    _cancel?.cancel();
  }

  Future<bool> _runMutation(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await action();
      if (refreshAfter) {
        _raw = await _helper.listDir(currentPath);
        await ConfigService.saveSftpLastPath(currentPath);
      }
      return true;
    } catch (e) {
      if (!_isCancelledError(e)) {
        error = e.toString();
      }
      return false;
    } finally {
      loading = false;
      _clearTransfer();
      notifyListeners();
    }
  }

  void _startTransfer({
    required String label,
    int? totalBytes,
  }) {
    _cancel = SftpCancelToken();
    transferLabel = label;
    transferBytes = 0;
    transferTotal = totalBytes;
    notifyListeners();
  }

  void _updateTransferProgress(int bytesTransferred, int? totalBytes) {
    transferBytes = bytesTransferred;
    transferTotal = totalBytes;
    notifyListeners();
  }

  void _clearTransfer() {
    _cancel = null;
    transferBytes = null;
    transferTotal = null;
    transferLabel = null;
  }

  bool _isCancelledError(Object error) {
    return error is StateError && error.message == 'Transfer cancelled';
  }

  String _fileNameFor(File file) {
    final segments = file.uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return file.path.split(Platform.pathSeparator).last;
  }

  String _joinLocalPath(String directoryPath, String fileName) {
    if (directoryPath.endsWith(Platform.pathSeparator)) {
      return '$directoryPath$fileName';
    }
    return '$directoryPath${Platform.pathSeparator}$fileName';
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _helper.close();
    super.dispose();
  }
}

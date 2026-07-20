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
  SftpController({SSHClient? client, SftpFileSystem? helper})
      : assert(client != null || helper != null),
        _helper = helper ?? SftpHelper(client!);

  final SftpFileSystem _helper;

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
  final Set<String> selectedNames = <String>{};
  bool selectionMode = false;

  void toggleSelectionMode([bool? enabled]) {
    selectionMode = enabled ?? !selectionMode;
    if (!selectionMode) {
      selectedNames.clear();
    }
    notifyListeners();
  }

  void toggleSelected(RemoteFsEntry entry) {
    if (entry.isParentLink) {
      return;
    }
    if (selectedNames.contains(entry.name)) {
      selectedNames.remove(entry.name);
    } else {
      selectedNames.add(entry.name);
    }
    if (selectedNames.isEmpty) {
      selectionMode = false;
    } else {
      selectionMode = true;
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedNames.clear();
    selectionMode = false;
    notifyListeners();
  }

  List<RemoteFsEntry> get selectedEntries => _raw
      .where((e) => selectedNames.contains(e.name))
      .toList(growable: false);

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
      final bool restoredPath = savedPath != null && savedPath.isNotEmpty;
      if (savedPath != null && savedPath.isNotEmpty) {
        currentPath = RemotePath.normalize(savedPath);
      } else if (drives.isNotEmpty) {
        currentPath = '${drives.first}:/';
      } else {
        currentPath = '/';
      }
      if (error == null) {
        await refresh(recoverInvalidPath: restoredPath);
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
  }

  Future<void> refresh({bool recoverInvalidPath = false}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _loadAndPersistCurrentPath();
    } catch (e) {
      if (recoverInvalidPath && await _tryFallbackPath()) {
        error = null;
      } else {
        if (recoverInvalidPath) {
          await ConfigService.clearSftpLastPath();
        }
        error = e.toString();
        _raw = <RemoteFsEntry>[];
      }
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
    if (entry.isParentLink) {
      return false;
    }

    if (entry.isDirectory) {
      final int completed = await downloadDirectory(entry, localDirectory);
      return completed > 0 && error == null;
    }

    final filename = (localName ?? entry.name).trim();
    if (filename.isEmpty) {
      return false;
    }

    final remotePath = RemotePath.join(currentPath, entry.name);
    final localPath = _joinLocalPath(localDirectory.path, filename);
    final localFile = File(localPath);

    final success = await _runMutation(() async {
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

    if (!success) {
      await _deletePartialLocalFile(localFile);
    }
    return success;
  }

  /// Recursively downloads [entry] (a remote directory) into [localDirectory].
  ///
  /// Returns the number of files transferred (directories are not counted).
  Future<int> downloadDirectory(
    RemoteFsEntry entry,
    Directory localDirectory,
  ) async {
    if (!entry.isDirectory || entry.isParentLink) {
      return 0;
    }

    final remoteRoot = RemotePath.join(currentPath, entry.name);
    final localRoot = Directory(
      _joinLocalPath(localDirectory.path, entry.name),
    );

    loading = true;
    error = null;
    notifyListeners();

    try {
      await localRoot.create(recursive: true);
      final int completed = await _downloadTree(
        remoteDir: remoteRoot,
        localDir: localRoot,
      );
      return completed;
    } catch (e) {
      if (!_isCancelledError(e)) {
        error = e.toString();
      }
      return 0;
    } finally {
      loading = false;
      _clearTransfer();
      notifyListeners();
    }
  }

  /// Sequentially downloads selected files and folders into [localDirectory].
  Future<int> downloadSelected(Directory localDirectory) async {
    final entries = selectedEntries.toList(growable: false);
    var completed = 0;
    for (final entry in entries) {
      if (entry.isDirectory) {
        final int n = await downloadDirectory(entry, localDirectory);
        if (n == 0 && error != null) {
          break;
        }
        completed += n;
      } else {
        final ok = await download(entry, localDirectory);
        if (!ok) {
          break;
        }
        completed++;
      }
    }
    clearSelection();
    return completed;
  }

  /// Sequentially uploads [files], stopping on cancel/error.
  Future<int> uploadMany(List<File> files) async {
    var completed = 0;
    for (final file in files) {
      final ok = await upload(file);
      if (!ok) {
        break;
      }
      completed++;
    }
    return completed;
  }

  /// Recursively uploads [localDirectory] under the current remote path.
  ///
  /// Returns the number of files uploaded.
  Future<int> uploadDirectory(
    Directory localDirectory, {
    String? remoteName,
  }) async {
    final folderName =
        (remoteName ?? _directoryNameFor(localDirectory)).trim();
    if (folderName.isEmpty) {
      return 0;
    }

    final remoteRoot = RemotePath.join(currentPath, folderName);

    loading = true;
    error = null;
    notifyListeners();

    try {
      try {
        await _helper.mkdir(remoteRoot);
      } catch (_) {
        // Directory may already exist; continue uploading into it.
      }
      final int completed = await _uploadTree(
        localDir: localDirectory,
        remoteDir: remoteRoot,
      );
      await _loadAndPersistCurrentPath();
      return completed;
    } catch (e) {
      if (!_isCancelledError(e)) {
        error = e.toString();
      }
      return 0;
    } finally {
      loading = false;
      _clearTransfer();
      notifyListeners();
    }
  }

  /// Moves [entry] to [destinationDir] (same host) via rename.
  Future<bool> moveEntry(RemoteFsEntry entry, String destinationDir) async {
    if (entry.isParentLink) {
      return false;
    }
    final fromPath = RemotePath.join(currentPath, entry.name);
    final toPath = RemotePath.join(destinationDir, entry.name);
    return _runMutation(() async {
      await _helper.rename(fromPath, toPath);
    });
  }

  /// Copies a file within the remote filesystem (capped stream via helper).
  Future<bool> copyEntry(RemoteFsEntry entry, String destinationDir) async {
    if (entry.isDirectory || entry.isParentLink) {
      return false;
    }
    final fromPath = RemotePath.join(currentPath, entry.name);
    final toPath = RemotePath.join(destinationDir, entry.name);
    return _runMutation(() async {
      await _helper.copyRemoteFile(fromPath, toPath);
    });
  }

  Future<bool> remoteFileExists(String fileName) async {
    final targetName = fileName.trim();
    if (targetName.isEmpty) {
      return false;
    }
    return _helper.exists(RemotePath.join(currentPath, targetName));
  }

  String localDownloadPath(Directory localDirectory, String fileName) {
    return _joinLocalPath(localDirectory.path, fileName);
  }

  String remotePathForEntry(RemoteFsEntry entry) {
    return RemotePath.join(currentPath, entry.name);
  }

  Future<Uint8List> readRemoteBytes(
    RemoteFsEntry entry, {
    int maxBytes = kSftpPreviewMaxBytes,
  }) {
    if (entry.isDirectory || entry.isParentLink) {
      throw StateError('Only files can be previewed.');
    }
    return _helper.readRemoteBytes(
      remotePathForEntry(entry),
      maxBytes: maxBytes,
    );
  }

  Future<void> writeRemoteBytes(RemoteFsEntry entry, Uint8List data) async {
    if (entry.isDirectory || entry.isParentLink) {
      throw StateError('Only files can be edited.');
    }
    await _helper.writeRemoteBytes(remotePathForEntry(entry), data);
    await refresh();
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
    _cancel ??= SftpCancelToken();
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

  Future<void> _loadAndPersistCurrentPath() async {
    _raw = await _helper.listDir(currentPath);
    await ConfigService.saveSftpLastPath(currentPath);
  }

  Future<bool> _tryFallbackPath() async {
    for (final candidate in _fallbackPaths()) {
      try {
        currentPath = candidate;
        await _loadAndPersistCurrentPath();
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Iterable<String> _fallbackPaths() sync* {
    if (drives.isNotEmpty) {
      final driveRoot = '${drives.first}:/';
      if (driveRoot != currentPath) {
        yield driveRoot;
      }
    }
    if (currentPath != '/') {
      yield '/';
    }
  }

  String _fileNameFor(File file) {
    final segments = file.uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return file.path.split(Platform.pathSeparator).last;
  }

  String _directoryNameFor(Directory directory) {
    final segments = directory.uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return directory.path.split(Platform.pathSeparator).last;
  }

  Future<int> _downloadTree({
    required String remoteDir,
    required Directory localDir,
  }) async {
    final entries = await _helper.listDir(remoteDir);
    var completed = 0;
    for (final entry in entries) {
      if (_cancel?.isCancelled ?? false) {
        throw StateError('Transfer cancelled');
      }
      final remotePath = RemotePath.join(remoteDir, entry.name);
      final localPath = _joinLocalPath(localDir.path, entry.name);
      if (entry.isDirectory) {
        final subDir = Directory(localPath);
        await subDir.create(recursive: true);
        completed += await _downloadTree(
          remoteDir: remotePath,
          localDir: subDir,
        );
      } else {
        final localFile = File(localPath);
        _startTransfer(
          label: 'Downloading ${entry.name}',
          totalBytes: entry.size,
        );
        try {
          await _helper.downloadStream(
            remotePath,
            localFile,
            knownSize: entry.size,
            onProgress: (bytesTransferred, knownTotalBytes) {
              _updateTransferProgress(bytesTransferred, knownTotalBytes);
            },
            cancelToken: _cancel,
          );
          completed++;
        } catch (e) {
          await _deletePartialLocalFile(localFile);
          rethrow;
        }
      }
    }
    return completed;
  }

  Future<int> _uploadTree({
    required Directory localDir,
    required String remoteDir,
  }) async {
    var completed = 0;
    await for (final entity in localDir.list(followLinks: false)) {
      if (_cancel?.isCancelled ?? false) {
        throw StateError('Transfer cancelled');
      }
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final remotePath = RemotePath.join(remoteDir, name);
      if (entity is Directory) {
        try {
          await _helper.mkdir(remotePath);
        } catch (_) {
          // May already exist.
        }
        completed += await _uploadTree(
          localDir: entity,
          remoteDir: remotePath,
        );
      } else if (entity is File) {
        final totalBytes = await entity.length();
        _startTransfer(
          label: 'Uploading $name',
          totalBytes: totalBytes,
        );
        await _helper.upload(
          entity,
          remotePath,
          onProgress: (bytesTransferred, knownTotalBytes) {
            _updateTransferProgress(bytesTransferred, knownTotalBytes);
          },
          cancelToken: _cancel,
        );
        completed++;
      }
    }
    return completed;
  }

  String _joinLocalPath(String directoryPath, String fileName) {
    if (directoryPath.endsWith(Platform.pathSeparator)) {
      return '$directoryPath$fileName';
    }
    return '$directoryPath${Platform.pathSeparator}$fileName';
  }

  Future<void> _deletePartialLocalFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup after cancel/failure.
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _helper.close();
    super.dispose();
  }
}

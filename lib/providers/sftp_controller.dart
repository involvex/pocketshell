import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/models/sftp_transfer_job.dart';
import 'package:ssh_app/services/config_repository.dart';
import 'package:ssh_app/services/sftp_checksum_service.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';

/// Session-scoped SFTP explorer state and file operations.
class SftpController extends ChangeNotifier {
  SftpController({
    SSHClient? client,
    SftpFileSystem? helper,
    ConfigRepository? config,
    SftpChecksumService? checksum,
  })  : assert(client != null || helper != null),
        _helper = helper ?? SftpHelper(client!),
        _config = config ?? ConfigServiceRepository(),
        _checksum = checksum ?? (client != null ? SftpChecksumService(client) : null);

  final SftpFileSystem _helper;
  final ConfigRepository _config;
  final SftpChecksumService? _checksum;

  final List<SftpTransferJob> _queue = <SftpTransferJob>[];
  SftpTransferJob? _activeJob;
  bool _isPumping = false;
  int _nextJobId = 0;
  bool _verifyTransfers = true;
  String? _transferVerifyMessage;

  String _currentPath = '/';
  final List<RemoteFsEntry> _raw = <RemoteFsEntry>[];
  final List<String> _drives = <String>[];
  bool _loading = false;
  String? _error;
  String _filterTerm = '';
  RemoteFsSortField _sortField = RemoteFsSortField.name;
  bool _sortAscending = true;

  int? _transferBytes;
  int? _transferTotal;
  String? _transferLabel;
  SftpCancelToken? _cancel;
  final Set<String> _selectedNames = <String>{};
  bool _selectionMode = false;

  Timer? _progressThrottleTimer;
  bool _disposed = false;

  String get currentPath => _currentPath;
  List<String> get drives => List<String>.unmodifiable(_drives);
  bool get loading => _loading;
  String? get error => _error;
  String get filterTerm => _filterTerm;
  RemoteFsSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  int? get transferBytes => _transferBytes;
  int? get transferTotal => _transferTotal;
  String? get transferLabel => _transferLabel;

  List<SftpTransferJob> get queue => List<SftpTransferJob>.unmodifiable(_queue);
  SftpTransferJob? get activeJob => _activeJob;
  int get queuedCount =>
      _queue.where((SftpTransferJob j) => j.status == SftpTransferStatus.queued).length;

  bool get verifyTransfers => _verifyTransfers;
  String? get transferVerifyMessage => _transferVerifyMessage;

  set verifyTransfers(bool value) {
    if (_verifyTransfers == value) {
      return;
    }
    _verifyTransfers = value;
    notifyListeners();
  }

  Set<String> get selectedNames => Set<String>.unmodifiable(_selectedNames);
  bool get selectionMode => _selectionMode;

  List<RemoteFsEntry> get selectedEntries => _raw
      .where((e) => _selectedNames.contains(e.name))
      .toList(growable: false);

  List<RemoteFsEntry> get visibleEntries {
    final entries = applyRemoteFsView(
      _raw,
      filter: _filterTerm,
      field: _sortField,
      ascending: _sortAscending,
    );
    if (RemotePath.isRoot(_currentPath)) {
      return List<RemoteFsEntry>.unmodifiable(entries);
    }
    return <RemoteFsEntry>[
      const RemoteFsEntry(name: '..', isDirectory: true),
      ...entries,
    ];
  }

  Future<void> init({String? initialPath}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final savedSortField = await _config.getSftpSortField();
      _sortField = RemoteFsSortField.values.firstWhere(
        (field) => field.name == savedSortField,
        orElse: () => RemoteFsSortField.name,
      );
      _sortAscending = await _config.getSftpSortAscending();
      _drives
        ..clear()
        ..addAll(await _helper.listDrives());

      final savedPath = initialPath ?? await _config.getSftpLastPath();
      final bool restoredPath = savedPath != null && savedPath.isNotEmpty;
      if (savedPath != null && savedPath.isNotEmpty) {
        _currentPath = RemotePath.normalize(savedPath);
      } else if (_drives.isNotEmpty) {
        _currentPath = '${_drives.first}:/';
      } else {
        _currentPath = '/';
      }
      if (_error == null) {
        await refresh(recoverInvalidPath: restoredPath);
      }
    } catch (e) {
      _error = e.toString();
      _drives.clear();
      _currentPath = '/';
      _raw.clear();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool recoverInvalidPath = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadAndPersistCurrentPath();
    } catch (e) {
      if (recoverInvalidPath && await _tryFallbackPath()) {
        _error = null;
      } else {
        if (recoverInvalidPath) {
          await _config.clearSftpLastPath();
        }
        _error = e.toString();
        _raw.clear();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> navigateTo(String path) async {
    _currentPath = RemotePath.normalize(path);
    _filterTerm = '';
    await refresh();
  }

  Future<void> openEntry(RemoteFsEntry entry) async {
    if (!entry.isDirectory) {
      return;
    }
    if (entry.isParentLink) {
      await navigateTo(RemotePath.parent(_currentPath));
      return;
    }
    await navigateTo(RemotePath.join(_currentPath, entry.name));
  }

  void setFilter(String value) {
    _filterTerm = value;
    notifyListeners();
  }

  Future<void> setSort(RemoteFsSortField field, {bool? ascending}) async {
    _sortField = field;
    if (ascending != null) {
      _sortAscending = ascending;
    }
    await _config.saveSftpSortField(field.name);
    await _config.saveSftpSortAscending(_sortAscending);
    notifyListeners();
  }

  Future<bool> mkdir(String name) async {
    final entryName = name.trim();
    if (entryName.isEmpty) {
      return false;
    }
    return _runMutation(() async {
      await _helper.mkdir(RemotePath.join(_currentPath, entryName));
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
      final fromPath = RemotePath.join(_currentPath, entry.name);
      final toPath = RemotePath.join(_currentPath, targetName);
      await _helper.rename(fromPath, toPath);
    });
  }

  Future<bool> deleteEntry(RemoteFsEntry entry) async {
    if (entry.isParentLink) {
      return false;
    }

    return _runMutation(() async {
      final path = RemotePath.join(_currentPath, entry.name);
      if (entry.isDirectory) {
        await _helper.removeDir(path);
      } else {
        await _helper.removeFile(path);
      }
    });
  }

  SftpTransferJob enqueueUpload(File localFile, {String? remoteName}) {
    final String filename = (remoteName ?? _fileNameFor(localFile)).trim();
    final String remotePath = RemotePath.join(_currentPath, filename);
    final int total = localFile.lengthSync();
    final SftpTransferJob job = SftpTransferJob(
      id: _allocateJobId(),
      direction: SftpTransferDirection.upload,
      remotePath: remotePath,
      localPath: localFile.path,
      label: 'Uploading $filename',
      knownSize: total,
    );
    _enqueue(job);
    return job;
  }

  SftpTransferJob enqueueDownload(
    RemoteFsEntry entry,
    Directory localDirectory, {
    String? localName,
  }) {
    final String filename = (localName ?? entry.name).trim();
    final String remotePath = RemotePath.join(_currentPath, entry.name);
    final String localPath = _joinLocalPath(localDirectory.path, filename);
    final SftpTransferJob job = SftpTransferJob(
      id: _allocateJobId(),
      direction: SftpTransferDirection.download,
      remotePath: remotePath,
      localPath: localPath,
      label: 'Downloading ${entry.name}',
      knownSize: entry.size,
    );
    _enqueue(job);
    return job;
  }

  void enqueueDownloadSelected(Directory localDirectory) {
    for (final RemoteFsEntry entry in selectedEntries) {
      if (entry.isDirectory) {
        final String remoteRoot = RemotePath.join(_currentPath, entry.name);
        final String localRoot =
            _joinLocalPath(localDirectory.path, entry.name);
        _enqueue(
          SftpTransferJob(
            id: _allocateJobId(),
            direction: SftpTransferDirection.download,
            remotePath: remoteRoot,
            localPath: localRoot,
            label: 'Downloading ${entry.name}',
            isDirectoryTree: true,
            refreshAfterSuccess: false,
          ),
        );
      } else {
        enqueueDownload(entry, localDirectory);
      }
    }
    unawaited(_pumpQueue());
  }

  List<SftpTransferJob> enqueueUploadMany(List<File> files) {
    final List<SftpTransferJob> jobs = <SftpTransferJob>[
      for (final File file in files) enqueueUpload(file),
    ];
    unawaited(_pumpQueue());
    return jobs;
  }

  Future<bool> upload(File localFile, {String? remoteName}) async {
    final String filename = (remoteName ?? _fileNameFor(localFile)).trim();
    if (filename.isEmpty) {
      return false;
    }
    final SftpTransferJob job = enqueueUpload(localFile, remoteName: remoteName);
    unawaited(_pumpQueue());
    return job.completer.future;
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
      return completed > 0 && _error == null;
    }

    final String filename = (localName ?? entry.name).trim();
    if (filename.isEmpty) {
      return false;
    }

    final SftpTransferJob job = enqueueDownload(
      entry,
      localDirectory,
      localName: localName,
    );
    unawaited(_pumpQueue());
    final bool success = await job.completer.future;
    if (!success) {
      await _deletePartialLocalFile(File(job.localPath));
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

    final String remoteRoot = RemotePath.join(_currentPath, entry.name);
    final String localRootPath =
        _joinLocalPath(localDirectory.path, entry.name);

    final SftpTransferJob job = SftpTransferJob(
      id: _allocateJobId(),
      direction: SftpTransferDirection.download,
      remotePath: remoteRoot,
      localPath: localRootPath,
      label: 'Downloading ${entry.name}',
      isDirectoryTree: true,
      refreshAfterSuccess: false,
    );
    _enqueue(job);
    unawaited(_pumpQueue());
    final bool ok = await job.completer.future;
    return ok ? (job.completedCount ?? 0) : 0;
  }

  /// Sequentially downloads selected files and folders into [localDirectory].
  Future<int> downloadSelected(Directory localDirectory) async {
    final int queueStart = _queue.length;
    enqueueDownloadSelected(localDirectory);
    final List<SftpTransferJob> jobs = _queue.sublist(queueStart);
    var completed = 0;
    for (final SftpTransferJob job in jobs) {
      final bool ok = await job.completer.future;
      if (!ok) {
        break;
      }
      completed += job.completedCount ?? 1;
    }
    clearSelection();
    return completed;
  }

  /// Sequentially uploads [files], stopping on cancel/error.
  Future<int> uploadMany(List<File> files) async {
    final List<SftpTransferJob> jobs = enqueueUploadMany(files);
    return _awaitUploadJobs(jobs);
  }

  /// Enqueues uploads with optional remote display names, then pumps the queue.
  Future<int> uploadNamedFiles(
    List<({File file, String? remoteName})> items,
  ) async {
    final List<SftpTransferJob> jobs = <SftpTransferJob>[
      for (final ({File file, String? remoteName}) item in items)
        enqueueUpload(item.file, remoteName: item.remoteName),
    ];
    unawaited(_pumpQueue());
    return _awaitUploadJobs(jobs);
  }

  Future<int> _awaitUploadJobs(List<SftpTransferJob> jobs) async {
    var completed = 0;
    for (final SftpTransferJob job in jobs) {
      if (await job.completer.future) {
        completed++;
      } else {
        break;
      }
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
    final String folderName =
        (remoteName ?? _directoryNameFor(localDirectory)).trim();
    if (folderName.isEmpty) {
      return 0;
    }

    final String remoteRoot = RemotePath.join(_currentPath, folderName);
    final SftpTransferJob job = SftpTransferJob(
      id: _allocateJobId(),
      direction: SftpTransferDirection.upload,
      remotePath: remoteRoot,
      localPath: localDirectory.path,
      label: 'Uploading $folderName',
      isDirectoryTree: true,
    );
    _enqueue(job);
    unawaited(_pumpQueue());
    final bool ok = await job.completer.future;
    return ok ? (job.completedCount ?? 0) : 0;
  }

  /// Moves [entry] to [destinationDir] (same host) via rename.
  Future<bool> moveEntry(RemoteFsEntry entry, String destinationDir) async {
    if (entry.isParentLink) {
      return false;
    }
    final fromPath = RemotePath.join(_currentPath, entry.name);
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
    final fromPath = RemotePath.join(_currentPath, entry.name);
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
    return _helper.exists(RemotePath.join(_currentPath, targetName));
  }

  String localDownloadPath(Directory localDirectory, String fileName) {
    return _joinLocalPath(localDirectory.path, fileName);
  }

  String remotePathForEntry(RemoteFsEntry entry) {
    return RemotePath.join(_currentPath, entry.name);
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

  Future<void> writeRemoteBytes(
    RemoteFsEntry entry,
    Uint8List data, {
    bool backup = true,
  }) async {
    if (entry.isDirectory || entry.isParentLink) {
      throw StateError('Only files can be edited.');
    }
    await _helper.writeRemoteBytes(
      remotePathForEntry(entry),
      data,
      backup: backup,
    );
    await refresh();
  }

  void cancelTransfer() {
    _cancel?.cancel();
  }

  void clearQueue() {
    for (final SftpTransferJob job in _queue) {
      if (job.status == SftpTransferStatus.queued) {
        job.status = SftpTransferStatus.cancelled;
        job.completeFailure(false);
      }
    }
    _queue.removeWhere(
      (SftpTransferJob job) => job.status == SftpTransferStatus.cancelled,
    );
    if (_activeJob != null) {
      _syncTransferFromJob(_activeJob!);
    } else {
      notifyListeners();
    }
  }

  Future<int?> statEntryMode(RemoteFsEntry entry) {
    if (entry.isParentLink) {
      return Future<int?>.value();
    }
    return _helper.statMode(remotePathForEntry(entry));
  }

  Future<bool> setPermissions(
    RemoteFsEntry entry,
    int mode, {
    bool recursive = false,
  }) async {
    if (entry.isParentLink) {
      return false;
    }
    final String path = remotePathForEntry(entry);
    if (!recursive || !entry.isDirectory) {
      return _runMutation(() => _helper.setPermissions(path, mode));
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _helper.setPermissions(path, mode);
      await _setPermissionsRecursive(path, mode);
      await _loadAndPersistCurrentPath();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void toggleSelectionMode([bool? enabled]) {
    _selectionMode = enabled ?? !_selectionMode;
    if (!_selectionMode) {
      _selectedNames.clear();
    }
    notifyListeners();
  }

  void toggleSelected(RemoteFsEntry entry) {
    if (entry.isParentLink) {
      return;
    }
    if (_selectedNames.contains(entry.name)) {
      _selectedNames.remove(entry.name);
    } else {
      _selectedNames.add(entry.name);
    }
    if (_selectedNames.isEmpty) {
      _selectionMode = false;
    } else {
      _selectionMode = true;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedNames.clear();
    _selectionMode = false;
    notifyListeners();
  }

  String _allocateJobId() {
    _nextJobId++;
    return 'sftp_job_$_nextJobId';
  }

  void _enqueue(SftpTransferJob job) {
    _queue.add(job);
    notifyListeners();
  }

  Future<void> _pumpQueue() async {
    if (_isPumping) {
      return;
    }
    _isPumping = true;
    try {
      while (true) {
        SftpTransferJob? next;
        for (final SftpTransferJob candidate in _queue) {
          if (candidate.status == SftpTransferStatus.queued) {
            next = candidate;
            break;
          }
        }
        if (next == null) {
          break;
        }
      _activeJob = next;
      next.status = SftpTransferStatus.active;
      _cancel = SftpCancelToken();
      next.bytes = 0;
      _syncTransferFromJob(next);
      notifyListeners();
      try {
        await _executeJob(next);
        if (_cancel?.isCancelled == true) {
          next.status = SftpTransferStatus.cancelled;
          next.completeFailure(false);
        } else {
          next.status = SftpTransferStatus.done;
          await _verifyJob(next);
          if (next.refreshAfterSuccess) {
            await _loadAndPersistCurrentPath();
          }
          next.completeSuccess();
        }
      } catch (e) {
        if (_isCancelledError(e) || _cancel?.isCancelled == true) {
          next.status = SftpTransferStatus.cancelled;
          next.error = e.toString();
          next.completeFailure(false);
        } else {
          next.status = SftpTransferStatus.failed;
          next.error = e.toString();
          _error = e.toString();
          next.completeFailure(false);
        }
        if (next.direction == SftpTransferDirection.download &&
            !next.isDirectoryTree) {
          await _deletePartialLocalFile(File(next.localPath));
        }
      } finally {
        _activeJob = null;
        _clearTransfer();
        notifyListeners();
      }
      }
    } finally {
      _isPumping = false;
    }
  }

  Future<void> _executeJob(SftpTransferJob job) async {
    if (job.isDirectoryTree) {
      if (job.direction == SftpTransferDirection.download) {
        final Directory localRoot = Directory(job.localPath);
        await localRoot.create(recursive: true);
        job.completedCount = await _downloadTree(
          remoteDir: job.remotePath,
          localDir: localRoot,
        );
        return;
      }
      try {
        await _helper.mkdir(job.remotePath);
      } catch (_) {
        // May already exist.
      }
      job.completedCount = await _uploadTree(
        localDir: Directory(job.localPath),
        remoteDir: job.remotePath,
      );
      return;
    }

    if (job.direction == SftpTransferDirection.upload) {
      final File localFile = File(job.localPath);
      final int totalBytes = await localFile.length();
      job.total = totalBytes;
      _syncTransferFromJob(job);
      await _helper.upload(
        localFile,
        job.remotePath,
        onProgress: (int bytesTransferred, int? knownTotalBytes) {
          _updateTransferProgress(bytesTransferred, knownTotalBytes);
        },
        cancelToken: _cancel,
      );
      return;
    }

    final File localFile = File(job.localPath);
    _syncTransferFromJob(job);
    await _helper.downloadStream(
      job.remotePath,
      localFile,
      knownSize: job.knownSize,
      resumeFromLocal: job.resumeDownload,
      onProgress: (int bytesTransferred, int? knownTotalBytes) {
        _updateTransferProgress(bytesTransferred, knownTotalBytes);
      },
      cancelToken: _cancel,
    );
  }

  Future<void> _verifyJob(SftpTransferJob job) async {
    _transferVerifyMessage = null;
    final checksum = _checksum;
    if (!_verifyTransfers ||
        job.isDirectoryTree ||
        checksum == null ||
        _cancel?.isCancelled == true) {
      return;
    }
    try {
      final String localHash =
          await checksum.localSha256(File(job.localPath));
      final String? remoteHash = await checksum.remoteSha256(job.remotePath);
      if (remoteHash == null) {
        _transferVerifyMessage = 'Checksum skipped (remote command unavailable)';
      } else if (localHash != remoteHash) {
        _transferVerifyMessage = 'Checksum mismatch';
        _error = 'Checksum mismatch for ${job.label}';
      } else {
        _transferVerifyMessage = 'Checksum verified';
      }
    } catch (e) {
      _transferVerifyMessage = 'Checksum failed: $e';
    }
    notifyListeners();
  }

  Future<void> _setPermissionsRecursive(String dirPath, int mode) async {
    final List<RemoteFsEntry> entries = await _helper.listDir(dirPath);
    for (final RemoteFsEntry entry in entries) {
      final String childPath = RemotePath.join(dirPath, entry.name);
      await _helper.setPermissions(childPath, mode);
      if (entry.isDirectory) {
        await _setPermissionsRecursive(childPath, mode);
      }
    }
  }

  void _syncTransferFromJob(SftpTransferJob job) {
    final int waiting = _queue
        .where(
          (SftpTransferJob j) => j.status == SftpTransferStatus.queued,
        )
        .length;
    var label = job.label;
    if (waiting > 0) {
      label = '$label (+$waiting queued)';
    }
    _transferLabel = label;
    _transferBytes = job.bytes;
    _transferTotal = job.total ?? job.knownSize;
  }

  Future<bool> _runMutation(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      if (refreshAfter) {
        _raw
          ..clear()
          ..addAll(await _helper.listDir(_currentPath));
        await _config.saveSftpLastPath(_currentPath);
      }
      return true;
    } catch (e) {
      if (!_isCancelledError(e)) {
        _error = e.toString();
      }
      return false;
    } finally {
      _loading = false;
      _clearTransfer();
      notifyListeners();
    }
  }

  void _startTransfer({
    required String label,
    int? totalBytes,
  }) {
    _cancel ??= SftpCancelToken();
    final SftpTransferJob? job = _activeJob;
    if (job != null) {
      job.label = label;
      job.bytes = 0;
      job.total = totalBytes ?? job.total;
      _syncTransferFromJob(job);
    } else {
      _transferLabel = label;
      _transferBytes = 0;
      _transferTotal = totalBytes;
    }
    notifyListeners();
  }

  void _updateTransferProgress(int bytesTransferred, int? totalBytes) {
    _transferBytes = bytesTransferred;
    _transferTotal = totalBytes;
    final SftpTransferJob? job = _activeJob;
    if (job != null) {
      job.bytes = bytesTransferred;
      job.total = totalBytes ?? job.total;
    }

    // Throttle notifyListeners to max 100ms to avoid jank
    if (_progressThrottleTimer?.isActive ?? false) {
      return;
    }
    _progressThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  void _clearTransfer() {
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = null;
    _cancel = null;
    _transferBytes = null;
    _transferTotal = null;
    _transferLabel = null;
  }

  bool _isCancelledError(Object error) {
    return error is StateError && error.message == 'Transfer cancelled';
  }

  Future<void> _loadAndPersistCurrentPath() async {
    _raw
      ..clear()
      ..addAll(await _helper.listDir(_currentPath));
    await _config.saveSftpLastPath(_currentPath);
  }

  Future<bool> _tryFallbackPath() async {
    for (final candidate in _fallbackPaths()) {
      try {
        _currentPath = candidate;
        await _loadAndPersistCurrentPath();
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Iterable<String> _fallbackPaths() sync* {
    if (_drives.isNotEmpty) {
      final driveRoot = '${_drives.first}:/';
      if (driveRoot != _currentPath) {
        yield driveRoot;
      }
    }
    if (_currentPath != '/') {
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
    _disposed = true;
    _progressThrottleTimer?.cancel();
    _cancel?.cancel();
    _helper.close();
    super.dispose();
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';

typedef SftpProgress = void Function(int bytesTransferred, int? totalBytes);

const int kSftpPreviewMaxBytes = 512 * 1024;
const Duration _drivesCacheTtl = Duration(minutes: 5);

abstract interface class SftpFileSystem {
  Future<List<RemoteFsEntry>> listDir(String path);
  Future<void> close();
  Future<void> mkdir(String path);
  Future<void> rename(String from, String to);
  Future<void> removeFile(String path);
  Future<void> removeDir(String path);
  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
  });
  Future<void> upload(
    File localFile,
    String remotePath, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  });
  Future<bool> exists(String path);
  Future<Uint8List> readRemoteBytes(
    String remotePath, {
    int maxBytes = kSftpPreviewMaxBytes,
  });
  Future<void> writeRemoteBytes(String remotePath, Uint8List data);
  Future<void> copyRemoteFile(String fromPath, String toPath);
  Future<String?> readRemoteText(String remotePath);
  Future<List<String>> listDrives({bool forceRefresh = false});
}

class SftpCancelToken {
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }
}

class SftpHelper implements SftpFileSystem {
  SftpHelper(this.client);
  final SSHClient client;
  SftpClient? _sftpClient;
  Future<SftpClient>? _sftpFuture;
  List<String>? _drives;
  DateTime? _drivesFetchedAt;

  Future<SftpClient> _sftp() {
    return _sftpFuture ??= client.sftp().then((SftpClient c) {
      _sftpClient = c;
      return c;
    });
  }

  @override
  Future<List<RemoteFsEntry>> listDir(String path) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(path);
    _validatePathTraversal(normalizedPath);
    final names = await sftp.listdir(normalizedPath);
    final entries = <RemoteFsEntry>[];
    for (final name in names) {
      final filename = name.filename.toString();
      if (filename == '.' || filename == '..') {
        continue;
      }
      entries.add(
        RemoteFsEntry(
          name: filename,
          isDirectory: name.attr.isDirectory,
          size: name.attr.size,
          modifyTime: name.attr.modifyTime,
        ),
      );
    }
    return entries;
  }

  @override
  Future<void> close() async {
    _sftpFuture = null;
    final c = _sftpClient;
    _sftpClient = null;
    c?.close();
    _drives = null;
    _drivesFetchedAt = null;
  }

  @override
  Future<void> mkdir(String path) async {
    final sftp = await _sftp();
    await sftp.mkdir(RemotePath.normalize(path));
  }

  @override
  Future<void> rename(String from, String to) async {
    final sftp = await _sftp();
    await sftp.rename(RemotePath.normalize(from), RemotePath.normalize(to));
  }

  @override
  Future<void> removeFile(String path) async {
    final sftp = await _sftp();
    await sftp.remove(RemotePath.normalize(path));
  }

  @override
  Future<void> removeDir(String path) async {
    final sftp = await _sftp();
    await sftp.rmdir(RemotePath.normalize(path));
  }

  @override
  Future<bool> exists(String path) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(path);
    try {
      await sftp.stat(normalizedPath);
      return true;
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    _validatePathTraversal(normalizedPath);
    final remoteFile = await sftp.open(
      normalizedPath,
      mode: SftpFileOpenMode.read,
    );
    final sink = localFile.openWrite();
    var transferred = 0;
    try {
      await for (final chunk in remoteFile.read()) {
        if (cancelToken?.isCancelled == true) {
          throw StateError('Transfer cancelled');
        }
        if (chunk.isEmpty) continue;
        sink.add(chunk);
        transferred += chunk.length;
        onProgress?.call(transferred, knownSize);
      }
      await sink.flush();
    } finally {
      await remoteFile.close();
      await sink.close();
    }
  }

  @override
  Future<void> upload(
    File localFile,
    String remotePath, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    _validatePathTraversal(normalizedPath);
    final file = await sftp.open(
      normalizedPath,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    final totalBytes = await localFile.length();
    try {
      var offset = 0;
      await for (final chunk in localFile.openRead()) {
        if (cancelToken?.isCancelled == true) {
          throw StateError('Transfer cancelled');
        }
        final bytes = Uint8List.fromList(chunk);
        await file.writeBytes(bytes, offset: offset);
        offset += bytes.length;
        onProgress?.call(offset, totalBytes);
      }
    } finally {
      await file.close();
    }
  }

  @override
  Future<Uint8List> readRemoteBytes(
    String remotePath, {
    int maxBytes = kSftpPreviewMaxBytes,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    _validatePathTraversal(normalizedPath);
    final int? knownSize = (await sftp.stat(normalizedPath)).size;
    if (knownSize != null && knownSize > maxBytes) {
      throw StateError(
        'Remote file is larger than the ${_formatPreviewLimit(maxBytes)} '
        'preview limit.',
      );
    }

    final remoteFile = await sftp.open(
      normalizedPath,
      mode: SftpFileOpenMode.read,
    );
    try {
      final buffer = BytesBuilder(copy: false);
      var totalBytes = 0;
      final int readLength = knownSize ?? maxBytes + 1;
      await for (final chunk in remoteFile.read(length: readLength)) {
        if (chunk.isEmpty) {
          continue;
        }
        totalBytes += chunk.length;
        if (totalBytes > maxBytes) {
          throw StateError(
            'Remote file is larger than the ${_formatPreviewLimit(maxBytes)} '
            'preview limit.',
          );
        }
        buffer.add(chunk);
      }
      return buffer.takeBytes();
    } finally {
      await remoteFile.close();
    }
  }

  @override
  Future<void> writeRemoteBytes(String remotePath, Uint8List data) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    _validatePathTraversal(normalizedPath);
    final remoteFile = await sftp.open(
      normalizedPath,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await remoteFile.writeBytes(data);
    } finally {
      await remoteFile.close();
    }
  }

  @override
  Future<void> copyRemoteFile(String fromPath, String toPath) async {
    final sftp = await _sftp();
    final sourcePath = RemotePath.normalize(fromPath);
    final destPath = RemotePath.normalize(toPath);
    _validatePathTraversal(sourcePath);
    _validatePathTraversal(destPath);
    final source = await sftp.open(sourcePath, mode: SftpFileOpenMode.read);
    final dest = await sftp.open(
      destPath,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      var offset = 0;
      await for (final chunk in source.read()) {
        if (chunk.isEmpty) continue;
        await dest.writeBytes(Uint8List.fromList(chunk), offset: offset);
        offset += chunk.length;
      }
    } finally {
      await source.close();
      await dest.close();
    }
  }

  @override
  Future<String?> readRemoteText(String remotePath) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    _validatePathTraversal(normalizedPath);
    try {
      final remoteFile =
          await sftp.open(normalizedPath, mode: SftpFileOpenMode.read);
      try {
        final buffer = BytesBuilder();
        await for (final chunk in remoteFile.read()) {
          if (chunk.isNotEmpty) {
            buffer.add(chunk);
          }
        }
        if (buffer.length == 0) return null;
        // Use utf8.decode with allowMalformed to handle multi-byte boundaries
        return utf8.decode(buffer.toBytes(), allowMalformed: true);
      } finally {
        await remoteFile.close();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listDrives({bool forceRefresh = false}) async {
    // Windows-only operation
    if (!Platform.isWindows) {
      return <String>[];
    }

    if (!forceRefresh &&
        _drives != null &&
        _drivesFetchedAt != null &&
        DateTime.now().difference(_drivesFetchedAt!) < _drivesCacheTtl) {
      return List<String>.from(_drives!);
    }

    final sftp = await _sftp();
    final drives = <String>[];

    // Parallelize drive checks with limited concurrency
    const int concurrency = 8;
    final futures = <Future<String?>>[];

    for (var codeUnit = 'C'.codeUnitAt(0);
        codeUnit <= 'Z'.codeUnitAt(0);
        codeUnit++) {
      final letter = String.fromCharCode(codeUnit);
      futures.add(_checkDrive(sftp, letter));

      if (futures.length >= concurrency) {
        final results = await Future.wait(futures);
        futures.clear();
        for (final result in results) {
          if (result != null) drives.add(result);
        }
      }
    }

    if (futures.isNotEmpty) {
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) drives.add(result);
      }
    }

    _drives = drives;
    _drivesFetchedAt = DateTime.now();
    return List<String>.from(drives);
  }

  static Future<String?> _checkDrive(SftpClient sftp, String letter) async {
    try {
      final path = '$letter:/';
      await sftp.listdir(path);
      return letter;
    } catch (_) {
      return null;
    }
  }

  /// Validates that [path] does not escape the intended root (traversal guard).
  /// Call with RemotePath.normalize(path) result.
  static void _validatePathTraversal(String path) {
    // On Windows, allow absolute paths like C:/...
    if (Platform.isWindows) {
      if (!RegExp(r'^[A-Za-z]:/').hasMatch(path)) {
        // Not an absolute Windows path - treat as relative
        if (path.contains('..')) {
          throw StateError('Path traversal detected: $path');
        }
      }
    } else {
      // Unix-like: must not contain .. segments after normalization
      if (path.split('/').contains('..')) {
        throw StateError('Path traversal detected: $path');
      }
    }
  }
}

String _formatPreviewLimit(int maxBytes) {
  if (maxBytes % (1024 * 1024) == 0) {
    return '${maxBytes ~/ (1024 * 1024)} MB';
  }
  if (maxBytes % 1024 == 0) {
    return '${maxBytes ~/ 1024} KB';
  }
  return '$maxBytes bytes';
}

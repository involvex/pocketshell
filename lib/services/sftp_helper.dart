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
    bool resumeFromLocal = false,
  });
  Future<int?> statMode(String path);
  Future<void> setPermissions(String path, int mode);
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
  Future<void> writeRemoteBytes(
    String remotePath,
    Uint8List data, {
    bool backup = true,
  });
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
    RemotePath.assertNoTraversal(normalizedPath);
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
    await c?.close();
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
    bool resumeFromLocal = false,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    RemotePath.assertNoTraversal(normalizedPath);
    final remoteFile = await sftp.open(
      normalizedPath,
      mode: SftpFileOpenMode.read,
    );

    var offset = 0;
    if (resumeFromLocal && await localFile.exists()) {
      offset = await localFile.length();
    }

    final IOSink sink = offset > 0
        ? localFile.openWrite(mode: FileMode.append)
        : localFile.openWrite();

    var transferred = offset;
    if (offset > 0) {
      onProgress?.call(transferred, knownSize);
    }

    try {
      await for (final chunk in remoteFile.read(offset: offset)) {
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
  Future<int?> statMode(String path) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(path);
    RemotePath.assertNoTraversal(normalizedPath);
    final attrs = await sftp.stat(normalizedPath);
    return attrs.mode?.value;
  }

  @override
  Future<void> setPermissions(String path, int mode) async {
    // Soft-fail for hosts that reject mode bits (common on Windows OpenSSH).
    try {
      final sftp = await _sftp();
      final normalizedPath = RemotePath.normalize(path);
      RemotePath.assertNoTraversal(normalizedPath);
      await sftp.setStat(
        normalizedPath,
        SftpFileAttrs(mode: SftpFileMode.value(mode)),
      );
    } catch (_) {
      throw StateError('Permissions not supported');
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
    RemotePath.assertNoTraversal(normalizedPath);
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
    RemotePath.assertNoTraversal(normalizedPath);
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
  Future<void> writeRemoteBytes(
    String remotePath,
    Uint8List data, {
    bool backup = true,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
    RemotePath.assertNoTraversal(normalizedPath);
    final tempPath = '$normalizedPath.pocketshell.tmp';
    RemotePath.assertNoTraversal(tempPath);

    // Write to a sibling temp file first so a dropped link never truncates
    // the real target to an empty/partial file.
    final tempFile = await sftp.open(
      tempPath,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await tempFile.writeBytes(data);
    } finally {
      await tempFile.close();
    }

    final targetExisted = await exists(normalizedPath);
    if (targetExisted && backup) {
      final bakPath = '$normalizedPath.bak';
      try {
        if (await exists(bakPath)) {
          await removeFile(bakPath);
        }
        await rename(normalizedPath, bakPath);
      } catch (_) {
        // Soft-fail backup — still try to replace the target below.
        if (await exists(normalizedPath)) {
          await removeFile(normalizedPath);
        }
      }
    } else if (targetExisted) {
      // Windows OpenSSH often cannot rename over an existing file.
      await removeFile(normalizedPath);
    }

    try {
      await rename(tempPath, normalizedPath);
    } catch (_) {
      if (await exists(normalizedPath)) {
        await removeFile(normalizedPath);
      }
      await rename(tempPath, normalizedPath);
    }
  }

  @override
  Future<void> copyRemoteFile(String fromPath, String toPath) async {
    final sftp = await _sftp();
    final sourcePath = RemotePath.normalize(fromPath);
    final destPath = RemotePath.normalize(toPath);
    RemotePath.assertNoTraversal(sourcePath);
    RemotePath.assertNoTraversal(destPath);
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
    RemotePath.assertNoTraversal(normalizedPath);
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
    // Probe the *remote* host for Windows drive letters. The client OS does
    // not matter — Android talking to Windows OpenSSH still needs C:/ etc.
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

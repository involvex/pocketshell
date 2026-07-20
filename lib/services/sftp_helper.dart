import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';

typedef SftpProgress = void Function(int bytesTransferred, int? totalBytes);

class SftpCancelToken {
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }
}

class SftpHelper {
  SftpHelper(this.client);
  final SSHClient client;
  SftpClient? _sftpClient;
  Future<SftpClient>? _sftpFuture;
  List<String>? _drives;

  Future<SftpClient> _sftp() {
    return _sftpFuture ??= client.sftp().then((SftpClient c) {
      _sftpClient = c;
      return c;
    });
  }

  Future<List<RemoteFsEntry>> listDir(String path) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(path);
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

  Future<void> close() async {
    _sftpFuture = null;
    final c = _sftpClient;
    _sftpClient = null;
    c?.close();
    _drives = null;
  }

  Future<void> mkdir(String path) async {
    final sftp = await _sftp();
    await sftp.mkdir(RemotePath.normalize(path));
  }

  Future<void> rename(String from, String to) async {
    final sftp = await _sftp();
    await sftp.rename(RemotePath.normalize(from), RemotePath.normalize(to));
  }

  Future<void> removeFile(String path) async {
    final sftp = await _sftp();
    await sftp.remove(RemotePath.normalize(path));
  }

  Future<void> removeDir(String path) async {
    final sftp = await _sftp();
    await sftp.rmdir(RemotePath.normalize(path));
  }

  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
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

  Future<void> upload(
    File localFile,
    String remotePath, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
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

  Future<String?> readRemoteText(String remotePath) async {
    final sftp = await _sftp();
    final normalizedPath = RemotePath.normalize(remotePath);
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
        return String.fromCharCodes(buffer.toBytes());
      } finally {
        await remoteFile.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> listDrives({bool forceRefresh = false}) async {
    if (_drives != null && !forceRefresh) {
      return List<String>.from(_drives!);
    }
    final sftp = await _sftp();
    final drives = <String>[];
    for (var codeUnit = 'C'.codeUnitAt(0);
        codeUnit <= 'Z'.codeUnitAt(0);
        codeUnit++) {
      final letter = String.fromCharCode(codeUnit);
      try {
        final path = '$letter:/';
        await sftp.listdir(path);
        drives.add(letter);
      } catch (_) {}
    }
    _drives = drives;
    return List<String>.from(drives);
  }
}

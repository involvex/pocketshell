import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/providers/sftp_controller.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/services/sftp_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadPrefs(
      [Map<String, Object> values = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(values);
    await ConfigService.init();
  }

  group('SftpController', () {
    test('falls back to the first drive root on invalid saved path', () async {
      await loadPrefs(<String, Object>{'sftp_last_path': '/missing'});
      final controller = SftpController(
        helper: FakeSftpFileSystem(
          drives: const <String>['C', 'D'],
          directories: <String, List<RemoteFsEntry>>{
            'C:/': const <RemoteFsEntry>[],
          },
        ),
      );

      await controller.init();

      expect(controller.currentPath, 'C:/');
      expect(controller.error, isNull);
      expect(await ConfigService.getSftpLastPath(), 'C:/');
    });

    test('clears the saved path when all fallback locations fail', () async {
      await loadPrefs(<String, Object>{'sftp_last_path': '/missing'});
      final controller = SftpController(
        helper: FakeSftpFileSystem(),
      );

      await controller.init();

      expect(controller.currentPath, '/');
      expect(controller.error, isNotNull);
      expect(await ConfigService.getSftpLastPath(), isNull);
    });

    test('checks remote file existence in the current folder', () async {
      await loadPrefs();
      final controller = SftpController(
        helper: FakeSftpFileSystem(
          existingPaths: const <String>{'C:/docs/readme.txt'},
        ),
      );
      controller.currentPath = 'C:/docs';

      final exists = await controller.remoteFileExists('readme.txt');

      expect(exists, isTrue);
    });
  });
}

class FakeSftpFileSystem implements SftpFileSystem {
  FakeSftpFileSystem({
    this.drives = const <String>[],
    Map<String, List<RemoteFsEntry>> directories =
        const <String, List<RemoteFsEntry>>{},
    Set<String> existingPaths = const <String>{},
  })  : _directories = directories,
        _existingPaths = existingPaths;

  final Map<String, List<RemoteFsEntry>> _directories;
  final Set<String> _existingPaths;
  final List<String> drives;

  @override
  Future<void> close() async {}

  @override
  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> exists(String path) async => _existingPaths.contains(path);

  @override
  Future<List<RemoteFsEntry>> listDir(String path) async {
    final entries = _directories[path];
    if (entries == null) {
      throw StateError('Missing directory: $path');
    }
    return entries;
  }

  @override
  Future<List<String>> listDrives({bool forceRefresh = false}) async => drives;

  @override
  Future<void> mkdir(String path) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readRemoteText(String remotePath) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readRemoteBytes(
    String remotePath, {
    int maxBytes = kSftpPreviewMaxBytes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeDir(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFile(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> rename(String from, String to) {
    throw UnimplementedError();
  }

  @override
  Future<void> upload(
    File localFile,
    String remotePath, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeRemoteBytes(String remotePath, Uint8List data) {
    throw UnimplementedError();
  }
}

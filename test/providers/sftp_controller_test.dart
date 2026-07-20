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

    test('recursively downloads a remote directory tree', () async {
      await loadPrefs();
      final fake = FakeSftpFileSystem(
        directories: <String, List<RemoteFsEntry>>{
          'C:/': const <RemoteFsEntry>[
            RemoteFsEntry(name: 'proj', isDirectory: true),
          ],
          'C:/proj': const <RemoteFsEntry>[
            RemoteFsEntry(name: 'a.txt', isDirectory: false, size: 3),
            RemoteFsEntry(name: 'sub', isDirectory: true),
          ],
          'C:/proj/sub': const <RemoteFsEntry>[
            RemoteFsEntry(name: 'b.txt', isDirectory: false, size: 3),
          ],
        },
        fileContents: <String, List<int>>{
          'C:/proj/a.txt': <int>[1, 2, 3],
          'C:/proj/sub/b.txt': <int>[4, 5, 6],
        },
      );
      final controller = SftpController(helper: fake);
      controller.currentPath = 'C:/';

      final Directory temp = await Directory.systemTemp.createTemp(
        'sftp_dl_',
      );
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final int completed = await controller.downloadDirectory(
        const RemoteFsEntry(name: 'proj', isDirectory: true),
        temp,
      );

      expect(completed, 2);
      expect(
        await File('${temp.path}${Platform.pathSeparator}proj'
                '${Platform.pathSeparator}a.txt')
            .readAsBytes(),
        <int>[1, 2, 3],
      );
      expect(
        await File('${temp.path}${Platform.pathSeparator}proj'
                '${Platform.pathSeparator}sub'
                '${Platform.pathSeparator}b.txt')
            .readAsBytes(),
        <int>[4, 5, 6],
      );
    });

    test('recursively uploads a local directory tree', () async {
      await loadPrefs();
      final fake = FakeSftpFileSystem(
        directories: <String, List<RemoteFsEntry>>{
          'C:/': const <RemoteFsEntry>[],
        },
      );
      final controller = SftpController(helper: fake);
      controller.currentPath = 'C:/';

      final Directory temp = await Directory.systemTemp.createTemp(
        'sftp_ul_',
      );
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });
      final Directory src = Directory(
        '${temp.path}${Platform.pathSeparator}bundle',
      );
      await src.create();
      await File('${src.path}${Platform.pathSeparator}root.txt')
          .writeAsBytes(<int>[9]);
      final Directory nested = Directory(
        '${src.path}${Platform.pathSeparator}nested',
      );
      await nested.create();
      await File('${nested.path}${Platform.pathSeparator}child.txt')
          .writeAsBytes(<int>[8, 7]);

      final int completed = await controller.uploadDirectory(src);

      expect(completed, 2);
      expect(fake.uploadedPaths, containsAll(<String>[
        'C:/bundle/root.txt',
        'C:/bundle/nested/child.txt',
      ]));
      expect(fake.createdDirs, containsAll(<String>[
        'C:/bundle',
        'C:/bundle/nested',
      ]));
    });
  });
}

class FakeSftpFileSystem implements SftpFileSystem {
  FakeSftpFileSystem({
    this.drives = const <String>[],
    Map<String, List<RemoteFsEntry>> directories =
        const <String, List<RemoteFsEntry>>{},
    Set<String> existingPaths = const <String>{},
    Map<String, List<int>> fileContents = const <String, List<int>>{},
  })  : _directories = Map<String, List<RemoteFsEntry>>.from(directories),
        _existingPaths = Set<String>.from(existingPaths),
        _fileContents = Map<String, List<int>>.from(fileContents);

  final Map<String, List<RemoteFsEntry>> _directories;
  final Set<String> _existingPaths;
  final Map<String, List<int>> _fileContents;
  final List<String> drives;
  final List<String> uploadedPaths = <String>[];
  final List<String> createdDirs = <String>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
  }) async {
    final bytes = _fileContents[remotePath];
    if (bytes == null) {
      throw StateError('Missing remote file: $remotePath');
    }
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(bytes, flush: true);
    onProgress?.call(bytes.length, knownSize ?? bytes.length);
  }

  @override
  Future<bool> exists(String path) async => _existingPaths.contains(path);

  @override
  Future<List<RemoteFsEntry>> listDir(String path) async {
    final entries = _directories[path];
    if (entries == null) {
      throw StateError('Missing directory: $path');
    }
    return List<RemoteFsEntry>.from(entries);
  }

  @override
  Future<List<String>> listDrives({bool forceRefresh = false}) async => drives;

  @override
  Future<void> mkdir(String path) async {
    createdDirs.add(path);
    _directories.putIfAbsent(path, () => <RemoteFsEntry>[]);
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
  }) async {
    final bytes = await localFile.readAsBytes();
    uploadedPaths.add(remotePath);
    _fileContents[remotePath] = bytes;
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> writeRemoteBytes(String remotePath, Uint8List data) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyRemoteFile(String fromPath, String toPath) {
    throw UnimplementedError();
  }
}

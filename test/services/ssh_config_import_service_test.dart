import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/services/sftp_helper.dart';
import 'package:ssh_app/services/ssh_config_import_service.dart';

String _fixturePem() =>
    File('test/fixtures/id_ed25519_unencrypted').readAsStringSync();

void main() {
  group('SshConfigImportService.mergeIntoProfiles', () {
    test('creates and updates without overwriting passwords', () {
      const importer = SshConfigImportService();
      final existing = <SSHProfile>[
        SSHProfile(
          id: 'keep-id',
          name: 'Old Name',
          host: '192.168.1.10',
          port: 2222,
          username: 'lukas',
          password: '<<keep-me>>',
        ),
      ];

      const raw = '''
Host lab
  HostName 192.168.1.10
  User lukas
  Port 2222

Host other
  HostName 10.0.0.2
  User admin
''';

      final merged = importer.mergeIntoProfiles(
        existing: existing,
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      expect(merged.result.created, 1);
      expect(merged.result.updated, 1);
      expect(merged.profiles, hasLength(2));
      expect(merged.pendingIdentityFiles, isEmpty);

      final updated = merged.profiles.firstWhere((p) => p.id == 'keep-id');
      expect(updated.name, 'lab');
      expect(updated.password, '<<keep-me>>');

      final created = merged.profiles.firstWhere((p) => p.name == 'other');
      expect(created.host, '10.0.0.2');
      expect(created.username, 'admin');
      expect(created.password, isNull);
    });

    test('resolves ProxyJump to an existing profile by alias', () {
      const importer = SshConfigImportService();
      final existing = <SSHProfile>[
        SSHProfile(
          id: 'bastion-id',
          name: 'bastion',
          host: '10.0.0.1',
          username: 'ops',
        ),
      ];

      const raw = '''
Host winlab
  HostName 10.0.0.50
  User lukas
  ProxyJump bastion
  LocalForward 3389 127.0.0.1:3389
''';

      final merged = importer.mergeIntoProfiles(
        existing: existing,
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final win = merged.profiles.firstWhere((p) => p.name == 'winlab');
      expect(win.jumpProfileId, 'bastion-id');
      expect(win.localForwards, hasLength(1));
      expect(win.localForwards.single.localPort, 3389);
      expect(merged.result.unresolvedProxyJumps, isEmpty);
    });

    test('queues IdentityFile paths without attaching keys yet', () {
      const importer = SshConfigImportService();
      const raw = '''
Host lab
  HostName 10.0.0.9
  User lukas
  IdentityFile ~/.ssh/id_ed25519
''';

      final merged = importer.mergeIntoProfiles(
        existing: const <SSHProfile>[],
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final lab = merged.profiles.single;
      expect(lab.privateKey, isNull);
      expect(merged.pendingIdentityFiles[lab.id], '~/.ssh/id_ed25519');
      expect(merged.result.identityHints, isEmpty);
    });
  });

  group('SshConfigImportService.pullIdentityFiles', () {
    test('attaches a pulled PEM key to a profile without a key', () async {
      const importer = SshConfigImportService();
      final pem = _fixturePem();
      const raw = '''
Host lab
  HostName 10.0.0.9
  User lukas
  IdentityFile ~/.ssh/id_ed25519
''';
      final merged = importer.mergeIntoProfiles(
        existing: const <SSHProfile>[],
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final helper = _RecordingSftp(
        files: <String, List<int>>{
          'C:/Users/lukas/.ssh/id_ed25519': utf8.encode(pem),
        },
      );

      final pulled = await importer.pullIdentityFiles(
        profiles: merged.profiles,
        pendingIdentityFiles: merged.pendingIdentityFiles,
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
        helper: helper,
        baseResult: merged.result,
      );

      expect(pulled.keys, hasLength(1));
      expect(pulled.result.identityPulled, hasLength(1));
      expect(pulled.result.identityHints, isEmpty);

      final lab = pulled.profiles.single;
      expect(lab.privateKey, pulled.keys.single.id);
      expect(pulled.keys.single.publicKey, startsWith('ssh-ed25519 '));
      expect(helper.readPaths, contains('C:/Users/lukas/.ssh/id_ed25519'));
    });

    test('keeps existing key and records a hint', () async {
      const importer = SshConfigImportService();
      final existing = <SSHProfile>[
        SSHProfile(
          id: 'keep-id',
          name: 'lab',
          host: '10.0.0.9',
          username: 'lukas',
          privateKey: 'existing-key-id',
        ),
      ];
      const raw = '''
Host lab
  HostName 10.0.0.9
  User lukas
  IdentityFile ~/.ssh/id_ed25519
''';
      final merged = importer.mergeIntoProfiles(
        existing: existing,
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final pulled = await importer.pullIdentityFiles(
        profiles: merged.profiles,
        pendingIdentityFiles: merged.pendingIdentityFiles,
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
        helper: _RecordingSftp(),
        baseResult: merged.result,
      );

      expect(pulled.keys, isEmpty);
      expect(pulled.profiles.single.privateKey, 'existing-key-id');
      expect(pulled.result.identityHints.single, contains('already has a key'));
    });

    test('hints when the remote key is missing', () async {
      const importer = SshConfigImportService();
      const raw = '''
Host lab
  HostName 10.0.0.9
  User lukas
  IdentityFile ~/.ssh/missing
''';
      final merged = importer.mergeIntoProfiles(
        existing: const <SSHProfile>[],
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final pulled = await importer.pullIdentityFiles(
        profiles: merged.profiles,
        pendingIdentityFiles: merged.pendingIdentityFiles,
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
        helper: _RecordingSftp(),
        baseResult: merged.result,
      );

      expect(pulled.keys, isEmpty);
      expect(pulled.profiles.single.privateKey, isNull);
      expect(pulled.result.identityHints.single, contains('unreadable'));
    });

    test('reuses one key when two hosts share the same IdentityFile', () async {
      const importer = SshConfigImportService();
      final pem = _fixturePem();
      const raw = '''
Host a
  HostName 10.0.0.1
  User lukas
  IdentityFile ~/.ssh/id_ed25519

Host b
  HostName 10.0.0.2
  User lukas
  IdentityFile ~/.ssh/id_ed25519
''';
      final merged = importer.mergeIntoProfiles(
        existing: const <SSHProfile>[],
        sourcePath: 'C:/Users/lukas/.ssh/config',
        contents: raw,
        fallbackUsername: 'lukas',
      );

      final helper = _RecordingSftp(
        files: <String, List<int>>{
          'C:/Users/lukas/.ssh/id_ed25519': utf8.encode(pem),
        },
      );

      final pulled = await importer.pullIdentityFiles(
        profiles: merged.profiles,
        pendingIdentityFiles: merged.pendingIdentityFiles,
        configPath: 'C:/Users/lukas/.ssh/config',
        username: 'lukas',
        helper: helper,
        baseResult: merged.result,
      );

      expect(pulled.keys, hasLength(1));
      expect(pulled.result.identityPulled, hasLength(2));
      final ids = pulled.profiles.map((p) => p.privateKey).toSet();
      expect(ids, <String?>{pulled.keys.single.id});
      expect(
        helper.readPaths.where((p) => p.endsWith('id_ed25519')),
        hasLength(1),
      );
    });
  });
}

class _RecordingSftp implements SftpFileSystem {
  _RecordingSftp({Map<String, List<int>> files = const <String, List<int>>{}})
      : _files = Map<String, List<int>>.from(files);

  final Map<String, List<int>> _files;
  final List<String> readPaths = <String>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> copyRemoteFile(String fromPath, String toPath) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadStream(
    String remotePath,
    File localFile, {
    SftpProgress? onProgress,
    SftpCancelToken? cancelToken,
    int? knownSize,
    bool resumeFromLocal = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<List<RemoteFsEntry>> listDir(String path) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> listDrives({bool forceRefresh = false}) async =>
      const <String>[];

  @override
  Future<void> mkdir(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readRemoteBytes(
    String remotePath, {
    int maxBytes = kSftpPreviewMaxBytes,
  }) async {
    readPaths.add(remotePath);
    final bytes = _files[remotePath];
    if (bytes == null) {
      throw StateError('Missing remote file: $remotePath');
    }
    if (bytes.length > maxBytes) {
      throw StateError('too large');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<String?> readRemoteText(String remotePath) async {
    final bytes = await readRemoteBytes(remotePath);
    return utf8.decode(bytes);
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
  Future<void> setPermissions(String path, int mode) {
    throw UnimplementedError();
  }

  @override
  Future<int?> statMode(String path) async => null;

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
  Future<void> writeRemoteBytes(
    String remotePath,
    Uint8List data, {
    bool backup = true,
  }) {
    throw UnimplementedError();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/config_repository.dart';
import 'package:ssh_app/services/share_clone_handler.dart';
import 'package:ssh_app/services/share_intent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('ShareIntentService.parseGitUrl', () {
    test('extracts github https URL and appends .git', () {
      expect(
        ShareIntentService.parseGitUrl(
          'Check this out https://github.com/owner/repo',
        ),
        'https://github.com/owner/repo.git',
      );
    });

    test('keeps existing .git suffix', () {
      expect(
        ShareIntentService.parseGitUrl(
          'https://github.com/owner/repo.git',
        ),
        'https://github.com/owner/repo.git',
      );
    });

    test('strips tree path from github URL', () {
      expect(
        ShareIntentService.parseGitUrl(
          'https://github.com/owner/repo/tree/main/lib',
        ),
        'https://github.com/owner/repo.git',
      );
    });

    test('parses git@ SSH URLs', () {
      expect(
        ShareIntentService.parseGitUrl(
          'git@github.com:owner/repo.git',
        ),
        'git@github.com:owner/repo.git',
      );
    });

    test('parses bare github.com paths', () {
      expect(
        ShareIntentService.parseGitUrl('github.com/owner/repo'),
        'https://github.com/owner/repo.git',
      );
    });

    test('accepts non-github https clone URLs', () {
      expect(
        ShareIntentService.parseGitUrl(
          'https://gitlab.com/group/project.git',
        ),
        'https://gitlab.com/group/project.git',
      );
    });

    test('returns null when no URL is present', () {
      expect(ShareIntentService.parseGitUrl('hello world'), isNull);
      expect(ShareIntentService.parseGitUrl(''), isNull);
    });

    test('strips trailing punctuation', () {
      expect(
        ShareIntentService.parseGitUrl(
          'See https://github.com/owner/repo).',
        ),
        'https://github.com/owner/repo.git',
      );
    });
  });

  group('ShareIntentService.buildGitCloneCommand', () {
    test('builds paste-only command without newline', () {
      expect(
        ShareIntentService.buildGitCloneCommand(
          'https://github.com/owner/repo.git',
        ),
        'git clone https://github.com/owner/repo.git',
      );
    });
  });

  group('ShareCloneHandler.resolveShareProfile', () {
    test('prefers lastSession over other profiles', () async {
      final FakeConfigRepository repo = FakeConfigRepository();
      final SSHProvider ssh = SSHProvider(config: repo);
      final SSHProfile first = SSHProfile(
        name: 'A',
        host: 'a.example',
        username: 'u',
      );
      final SSHProfile second = SSHProfile(
        name: 'B',
        host: 'b.example',
        username: 'u',
      );
      await ssh.saveProfile(first);
      await ssh.saveProfile(second);
      await ssh.saveLastSession(second);

      expect(ShareCloneHandler.resolveShareProfile(ssh)?.id, second.id);
    });

    test('falls back to first non-server profile', () async {
      final FakeConfigRepository repo = FakeConfigRepository();
      final SSHProvider ssh = SSHProvider(config: repo);
      final SSHProfile server = SSHProfile(
        name: 'Server',
        host: 's.example',
        username: 'u',
        isServer: true,
      );
      final SSHProfile client = SSHProfile(
        name: 'Client',
        host: 'c.example',
        username: 'u',
      );
      await ssh.saveProfile(server);
      await ssh.saveProfile(client);

      expect(ShareCloneHandler.resolveShareProfile(ssh)?.id, client.id);
    });

    test('returns null when no client profiles exist', () async {
      final FakeConfigRepository repo = FakeConfigRepository();
      final SSHProvider ssh = SSHProvider(config: repo);
      await ssh.saveProfile(
        SSHProfile(
          name: 'Server',
          host: 's.example',
          username: 'u',
          isServer: true,
        ),
      );

      expect(ShareCloneHandler.resolveShareProfile(ssh), isNull);
    });
  });

  group('ShareCloneHandler.clientProfiles', () {
    test('excludes server profiles', () async {
      final FakeConfigRepository repo = FakeConfigRepository();
      final SSHProvider ssh = SSHProvider(config: repo);
      await ssh.saveProfile(
        SSHProfile(name: 'Server', host: 's.example', username: 'u',
            isServer: true),
      );
      final SSHProfile a = SSHProfile(
          name: 'A', host: 'a.example', username: 'u');
      final SSHProfile b = SSHProfile(
          name: 'B', host: 'b.example', username: 'u');
      await ssh.saveProfile(a);
      await ssh.saveProfile(b);

      final ids =
          ShareCloneHandler.clientProfiles(ssh).map((p) => p.id).toList();
      expect(ids, containsAll(<String>[a.id, b.id]));
      expect(ids, hasLength(2));
    });
  });

  group('ShareCloneHandler.showShareProfilePicker', () {
    testWidgets('preselects last-connected and returns chosen host',
        (tester) async {
      final a = SSHProfile(name: 'Alpha', host: 'a.example', username: 'u');
      final b = SSHProfile(name: 'Beta', host: 'b.example', username: 'u');

      SSHProfile? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ShareCloneHandler.showShareProfilePicker(
                  context,
                  [a, b],
                  initial: b,
                  gitUrl: 'https://github.com/owner/repo.git',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Clone to host'), findsOneWidget);
      expect(find.text('u@b.example:22 · last connected'), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clone here'));
      await tester.pumpAndSettle();

      expect(result?.id, a.id);
    });

    testWidgets('cancel returns null', (tester) async {
      final a = SSHProfile(name: 'Alpha', host: 'a.example', username: 'u');

      SSHProfile? result = a;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ShareCloneHandler.showShareProfilePicker(
                  context,
                  [a],
                  gitUrl: 'https://github.com/owner/repo.git',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}

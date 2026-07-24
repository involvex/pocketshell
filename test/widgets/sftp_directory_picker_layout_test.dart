import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';

void main() {
  testWidgets('directoriesOnly hides per-entry overflow menu',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SftpEntryList(
            entries: const <RemoteFsEntry>[
              RemoteFsEntry(
                name: 'projects',
                isDirectory: true,
                size: 0,
              ),
            ],
            currentPath: r'C:\',
            loading: false,
            directoriesOnly: true,
            onOpenEntry: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';
import 'package:ssh_app/widgets/sftp_directory_picker.dart';

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

  testWidgets('picker shell shows title, list region, and bottom actions',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SftpDirectoryPickerShell(
          header: const SizedBox(height: 48, child: Text('HEADER')),
          body: ListView(children: const <Widget>[Text('folder-a')]),
          onCancel: () {},
          onSelect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Project Directory'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('folder-a'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

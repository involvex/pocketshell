import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';

void _setPhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrapHeader({required bool showSectionTitle}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: SftpBrowserHeader(
          currentPath: r'C:\Users\dev\projects',
          drives: const <String>['C'],
          filterTerm: '',
          sortField: RemoteFsSortField.name,
          sortAscending: true,
          showSectionTitle: showSectionTitle,
          onCopyPath: () async {},
          onDriveSelected: (_) async {},
          onFilterChanged: (_) {},
          onSortChanged: (_, __) async {},
          onRefresh: () async {},
          onCreateDirectory: (_) async {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('compact layout does not render vertical Remote files letters',
      (WidgetTester tester) async {
    _setPhoneSurface(tester);
    await tester.pumpWidget(_wrapHeader(showSectionTitle: false));
    await tester.pumpAndSettle();

    expect(find.text('Remote files'), findsNothing);

    final RenderBox pathBox =
        tester.renderObject<RenderBox>(find.text(r'C:\Users\dev\projects'));
    expect(pathBox.size.width, greaterThan(200));
  });

  testWidgets('standard layout keeps section title on wide surface',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SftpBrowserHeader(
              currentPath: r'C:\Users\dev\projects',
              drives: const <String>['C'],
              filterTerm: '',
              sortField: RemoteFsSortField.name,
              sortAscending: true,
              onCopyPath: () async {},
              onDriveSelected: (_) async {},
              onFilterChanged: (_) {},
              onSortChanged: (_, __) async {},
              onRefresh: () async {},
              onCreateDirectory: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remote files'), findsOneWidget);
  });
}

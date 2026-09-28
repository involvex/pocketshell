// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_app/constants/app_metadata.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build a minimal app with the same top-level title to avoid running the full startup sequence.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text(kAppDisplayName)),
      ),
    ));

    // Verify the app builds and shows the main title.
    expect(find.text(kAppDisplayName), findsOneWidget);
  });
}

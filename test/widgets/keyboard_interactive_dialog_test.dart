import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_app/widgets/keyboard_interactive_dialog.dart';

void main() {
  group('showKeyboardInteractiveDialog', () {
    testWidgets('masks echo=false and returns answers', (tester) async {
      List<String>? answers;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  answers = await showKeyboardInteractiveDialog(
                    context,
                    SSHUserInfoRequest(
                      '2FA',
                      'Enter codes',
                      <SSHUserInfoPrompt>[
                        SSHUserInfoPrompt('Visible: ', true),
                        SSHUserInfoPrompt('TOTP: ', false),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('2FA'), findsOneWidget);
      expect(find.text('Enter codes'), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));

      final visible = tester.widget<TextField>(fields.at(0));
      final secret = tester.widget<TextField>(fields.at(1));
      expect(visible.obscureText, isFalse);
      expect(secret.obscureText, isTrue);

      await tester.enterText(fields.at(0), 'alice');
      await tester.enterText(fields.at(1), '123456');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(answers, <String>['alice', '123456']);
    });

    testWidgets('cancel returns null', (tester) async {
      List<String>? answers = <String>['sentinel'];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  answers = await showKeyboardInteractiveDialog(
                    context,
                    SSHUserInfoRequest(
                      '',
                      '',
                      <SSHUserInfoPrompt>[
                        SSHUserInfoPrompt('Password: ', false),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answers, isNull);
    });
  });
}

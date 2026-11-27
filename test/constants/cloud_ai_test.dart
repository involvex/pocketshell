import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/constants/cloud_ai.dart';

void main() {
  test('default build enables cloud AI (F-Droid NonFreeNet path)', () {
    // bool.fromEnvironment defaults are compile-time; unit tests see default.
    expect(kCloudAiEnabled, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/constants/agents.dart';

void main() {
  test('default build enables Agents tab (F-Droid path)', () {
    expect(kAgentsEnabled, isTrue);
  });
}

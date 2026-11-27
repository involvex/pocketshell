import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/startup_command_log.dart';

void main() {
  test('redacts argv after the first token', () {
    const cmd = 'git clone https://example.com/x.git';
    expect(redactStartupCommandLog(cmd), 'git … (${cmd.length} chars)');
  });
}

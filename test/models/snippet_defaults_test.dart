import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/snippet.dart';

void main() {
  test('defaults include unix and PowerShell packs', () {
    expect(Snippet.unixDefaults, isNotEmpty);
    expect(Snippet.windowsDefaults, isNotEmpty);
    expect(
      Snippet.defaults.length,
      Snippet.unixDefaults.length + Snippet.windowsDefaults.length,
    );
    expect(
      Snippet.windowsDefaults.every((s) => s.category == 'PowerShell'),
      isTrue,
    );
    expect(
      Snippet.windowsDefaults.any((s) => s.content.contains('Get-ChildItem')),
      isTrue,
    );
  });
}

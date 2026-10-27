import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/snippet.dart';
import 'package:ssh_app/providers/snippet_provider.dart';
import 'package:ssh_app/services/config_repository.dart';

class _MemoryConfig implements ConfigRepository {
  List<Map<String, dynamic>> snippets = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getSnippets() async => snippets;

  @override
  Future<void> saveSnippets(List<Map<String, dynamic>> value) async {
    snippets = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('reorderSnippets persists new order', () async {
    final config = _MemoryConfig()
      ..snippets = <Map<String, dynamic>>[
        Snippet(id: 'a', name: 'A', content: 'a').toJson(),
        Snippet(id: 'b', name: 'B', content: 'b').toJson(),
        Snippet(id: 'c', name: 'C', content: 'c').toJson(),
      ];
    final provider = SnippetProvider(config: config);
    await provider.loadSnippets();

    // onReorderItem: move index 0 into index 2 (already adjusted).
    await provider.reorderSnippets(0, 2);

    expect(
      provider.snippets.map((s) => s.id).toList(),
      <String>['b', 'c', 'a'],
    );
    expect(
      config.snippets.map((s) => s['id']).toList(),
      <String>['b', 'c', 'a'],
    );
  });
}

import 'package:flutter/foundation.dart';
import '../models/snippet.dart';
import '../services/config_service.dart';

class SnippetProvider extends ChangeNotifier {
  List<Snippet> _snippets = [];
  bool _isLoaded = false;

  List<Snippet> get snippets => _snippets;
  bool get isLoaded => _isLoaded;

  List<String> get categories {
    final cats = _snippets.map((s) => s.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Snippet> getSnippetsByCategory(String category) {
    return _snippets.where((s) => s.category == category).toList();
  }

  Future<void> loadSnippets() async {
    final data = await ConfigService.getSnippets();
    if (data.isNotEmpty) {
      _snippets = data
          .map((e) => Snippet.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      _snippets = Snippet.defaults;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addSnippet(Snippet snippet) async {
    _snippets.add(snippet);
    await _saveSnippets();
    notifyListeners();
  }

  Future<void> updateSnippet(Snippet snippet) async {
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    if (index >= 0) {
      _snippets[index] = snippet;
      await _saveSnippets();
      notifyListeners();
    }
  }

  Future<void> deleteSnippet(String id) async {
    _snippets.removeWhere((s) => s.id == id);
    await _saveSnippets();
    notifyListeners();
  }

  Future<void> resetSnippets() async {
    _snippets = Snippet.defaults;
    await _saveSnippets();
    notifyListeners();
  }

  Future<void> _saveSnippets() async {
    await ConfigService.saveSnippets(_snippets.map((s) => s.toJson()).toList());
  }
}

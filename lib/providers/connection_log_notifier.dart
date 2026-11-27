import 'package:flutter/foundation.dart';

/// In-app connection log, isolated from [SSHProvider] so log lines do not
/// rebuild the Client/Agents tabs.
class ConnectionLogNotifier extends ChangeNotifier {
  static const int maxLines = 100;

  final List<String> lines = <String>[];

  void add(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    lines.add('[$timestamp] $message');
    if (lines.length > maxLines) {
      lines.removeAt(0);
    }
    notifyListeners();
  }

  void clear() {
    if (lines.isEmpty) {
      return;
    }
    lines.clear();
    notifyListeners();
  }
}

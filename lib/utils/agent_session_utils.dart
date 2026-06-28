import 'package:opencode_api/opencode_api.dart';

import '../models/agent_connection.dart';

/// Sorts sessions by most recently updated first.
List<Session> sortSessionsByUpdatedDesc(List<Session> sessions) {
  final sorted = List<Session>.from(sessions);
  sorted.sort((Session a, Session b) {
    final aTime = a.time?.updated ?? a.time?.created ?? 0;
    final bTime = b.time?.updated ?? b.time?.created ?? 0;
    return bTime.compareTo(aTime);
  });
  return sorted;
}

/// Formats a Unix timestamp (seconds or milliseconds) for display.
String formatSessionTimestamp(int? timestamp) {
  if (timestamp == null) return '';
  final millis = timestamp > 9999999999 ? timestamp : timestamp * 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}

/// Returns the directory filter for session API calls, if any.
String? agentDirectoryScopeForConnection(AgentConnection connection) {
  final directory = connection.selectedDirectory;
  if (directory == null || directory.isEmpty) {
    return null;
  }
  return directory;
}

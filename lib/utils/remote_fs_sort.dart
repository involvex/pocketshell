import 'package:ssh_app/models/remote_fs_entry.dart';

enum RemoteFsSortField { name, date, size, type }

List<RemoteFsEntry> applyRemoteFsView(
  List<RemoteFsEntry> source, {
  required String filter,
  required RemoteFsSortField field,
  required bool ascending,
}) {
  final String q = filter.trim().toLowerCase();
  final List<RemoteFsEntry> filtered = q.isEmpty
      ? List<RemoteFsEntry>.from(source)
      : source.where((e) => e.name.toLowerCase().contains(q)).toList();

  int cmp(RemoteFsEntry a, RemoteFsEntry b) {
    if (a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    int raw;
    switch (field) {
      case RemoteFsSortField.name:
        raw = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case RemoteFsSortField.date:
        raw = (a.modifyTime ?? 0).compareTo(b.modifyTime ?? 0);
      case RemoteFsSortField.size:
        raw = (a.size ?? 0).compareTo(b.size ?? 0);
      case RemoteFsSortField.type:
        final String ae = a.name.contains('.') ? a.name.split('.').last : '';
        final String be = b.name.contains('.') ? b.name.split('.').last : '';
        raw = ae.toLowerCase().compareTo(be.toLowerCase());
        if (raw == 0) {
          raw = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
    }
    return ascending ? raw : -raw;
  }

  filtered.sort(cmp);
  return filtered;
}

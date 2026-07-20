import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';

void main() {
  final entries = <RemoteFsEntry>[
    const RemoteFsEntry(
      name: 'b.txt',
      isDirectory: false,
      size: 20,
      modifyTime: 2,
    ),
    const RemoteFsEntry(
      name: 'a_dir',
      isDirectory: true,
      size: 0,
      modifyTime: 3,
    ),
    const RemoteFsEntry(
      name: 'A.txt',
      isDirectory: false,
      size: 10,
      modifyTime: 1,
    ),
  ];

  test('filter is case-insensitive substring', () {
    final out = applyRemoteFsView(
      entries,
      filter: 'a.',
      field: RemoteFsSortField.name,
      ascending: true,
    );
    expect(out.map((e) => e.name), ['A.txt']);
  });

  test('directories sort before files when sorting by name', () {
    final out = applyRemoteFsView(
      entries,
      filter: '',
      field: RemoteFsSortField.name,
      ascending: true,
    );
    expect(out.first.name, 'a_dir');
  });

  test('sort by size ascending', () {
    final out = applyRemoteFsView(
      entries.where((e) => !e.isDirectory).toList(),
      filter: '',
      field: RemoteFsSortField.size,
      ascending: true,
    );
    expect(out.map((e) => e.name), ['A.txt', 'b.txt']);
  });
}

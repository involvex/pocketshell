class RemoteFsEntry {
  const RemoteFsEntry({
    required this.name,
    required this.isDirectory,
    this.size,
    this.modifyTime,
  });

  final String name;
  final bool isDirectory;
  final int? size;

  /// Seconds since epoch (SFTP mtime), if provided by server.
  final int? modifyTime;

  bool get isParentLink => name == '..';
}

import 'dart:async';

/// Direction of an SFTP transfer job.
enum SftpTransferDirection {
  upload,
  download,
}

/// Lifecycle status of a queued or active transfer.
enum SftpTransferStatus {
  queued,
  active,
  paused,
  done,
  failed,
  cancelled,
}

/// A single upload or download operation in the transfer queue.
class SftpTransferJob {
  SftpTransferJob({
    required this.id,
    required this.direction,
    required this.remotePath,
    required this.localPath,
    required this.label,
    this.knownSize,
    this.isDirectoryTree = false,
    this.refreshAfterSuccess = true,
    this.resumeDownload = true,
  })  : status = SftpTransferStatus.queued,
        bytes = 0;

  final String id;
  final SftpTransferDirection direction;
  final String remotePath;
  final String localPath;
  String label;
  final int? knownSize;
  final bool isDirectoryTree;
  final bool refreshAfterSuccess;

  /// When true, an existing non-empty local file is appended (download only).
  final bool resumeDownload;

  int bytes;
  int? total;
  SftpTransferStatus status;
  String? error;

  /// Files transferred when [isDirectoryTree] is true.
  int? completedCount;

  final Completer<bool> completer = Completer<bool>();

  void completeSuccess() {
    if (!completer.isCompleted) {
      completer.complete(true);
    }
  }

  void completeFailure([bool success = false]) {
    if (!completer.isCompleted) {
      completer.complete(success);
    }
  }
}
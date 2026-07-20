import 'package:flutter/material.dart';

/// Shared SFTP transfer status banner with cancel support.
class SftpTransferBanner extends StatelessWidget {
  const SftpTransferBanner({
    required this.label,
    required this.onCancel,
    this.transferredBytes,
    this.totalBytes,
    super.key,
  });

  final String label;
  final int? transferredBytes;
  final int? totalBytes;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasKnownTotal = totalBytes != null;
    final int currentBytes = transferredBytes ?? 0;
    final int? total = totalBytes;
    final double? progress = !hasKnownTotal
        ? null
        : total == 0
            ? 1
            : currentBytes.clamp(0, total!).toDouble() / total;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              hasKnownTotal
                  ? '${_formatBytes(currentBytes)} of ${_formatBytes(total!)}'
                  : 'Transferring ${_formatBytes(currentBytes)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  for (final String unit in units) {
    if (value < 1024 || unit == units.last) {
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} $unit';
    }
    value /= 1024;
  }
  return '$bytes B';
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

const Set<String> kSftpImagePreviewExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
};

/// Returns whether the remote file can be opened in the image preview.
bool isSftpImagePreviewExtension(String fileName) {
  final String? extension = _fileExtension(fileName);
  return extension != null && kSftpImagePreviewExtensions.contains(extension);
}

/// Loads a remote image file and presents it in a preview dialog.
Future<void> showSftpImagePreviewDialog({
  required BuildContext context,
  required String fileName,
  required Future<Uint8List> Function() onLoad,
}) async {
  try {
    final Uint8List bytes = await onLoad();
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SftpImagePreview(fileName: fileName, bytes: bytes);
      },
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    _showPreviewSnackBar(context, _previewErrorMessage(error));
  }
}

/// Remote image preview dialog content.
class SftpImagePreview extends StatelessWidget {
  const SftpImagePreview({
    required this.fileName,
    required this.bytes,
    super.key,
  });

  final String fileName;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 720,
        height: 640,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      fileName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Text('Failed to decode image.');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _fileExtension(String fileName) {
  final int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) {
    return null;
  }
  return fileName.substring(dotIndex).toLowerCase();
}

String _previewErrorMessage(Object error) {
  if (error is StateError) {
    return error.message.toString();
  }
  return 'Failed to open preview: $error';
}

void _showPreviewSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

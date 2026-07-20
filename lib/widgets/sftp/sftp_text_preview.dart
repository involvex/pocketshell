import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const Set<String> kSftpTextPreviewExtensions = <String>{
  '.txt',
  '.md',
  '.ini',
  '.env',
  '.json',
  '.yaml',
  '.yml',
  '.xml',
  '.log',
  '.csv',
};

/// Returns whether the remote file can be opened in the text editor preview.
bool isSftpTextPreviewExtension(String fileName) {
  final String? extension = _fileExtension(fileName);
  return extension != null && kSftpTextPreviewExtensions.contains(extension);
}

/// Loads a remote text file and presents an editable preview dialog.
Future<void> showSftpTextPreviewDialog({
  required BuildContext context,
  required String fileName,
  required Future<Uint8List> Function() onLoad,
  required Future<void> Function(Uint8List data) onSave,
}) async {
  try {
    final Uint8List bytes = await onLoad();
    if (!context.mounted) {
      return;
    }
    if (_looksBinary(bytes)) {
      _showPreviewSnackBar(context, 'Preview only supports text files.');
      return;
    }
    final String initialText = utf8.decode(bytes);
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SftpTextPreview(
          fileName: fileName,
          initialText: initialText,
          onSave: (String updatedText) {
            return onSave(Uint8List.fromList(utf8.encode(updatedText)));
          },
        );
      },
    );
    if (!context.mounted || saved != true) {
      return;
    }
    _showPreviewSnackBar(context, 'Saved');
  } on FormatException {
    if (!context.mounted) {
      return;
    }
    _showPreviewSnackBar(context, 'Preview only supports UTF-8 text files.');
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    _showPreviewSnackBar(context, _previewErrorMessage(error));
  }
}

/// Editable remote text preview dialog content.
class SftpTextPreview extends StatefulWidget {
  const SftpTextPreview({
    required this.fileName,
    required this.initialText,
    required this.onSave,
    super.key,
  });

  final String fileName;
  final String initialText;
  final Future<void> Function(String text) onSave;

  @override
  State<SftpTextPreview> createState() => _SftpTextPreviewState();
}

class _SftpTextPreviewState extends State<SftpTextPreview> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.onSave(_controller.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = _previewErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.fileName}'),
      content: SizedBox(
        width: 720,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_errorText != null) ...<Widget>[
              Text(
                _errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
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

bool _looksBinary(Uint8List bytes) {
  for (final int byte in bytes) {
    if (byte == 0) {
      return true;
    }
  }
  return false;
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

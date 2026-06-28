import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../services/sftp_helper.dart';

/// SFTP browser dialog that returns the selected remote directory path.
class SftpDirectoryPicker extends StatefulWidget {
  const SftpDirectoryPicker({
    required this.client,
    this.initialPath,
    super.key,
  });

  final SSHClient client;
  final String? initialPath;

  @override
  State<SftpDirectoryPicker> createState() => _SftpDirectoryPickerState();
}

class _SftpDirectoryPickerState extends State<SftpDirectoryPicker> {
  late String _currentPath;
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  List<String> _availableDrives = <String>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? '/';
    unawaited(_init());
  }

  Future<void> _init() async {
    final helper = SftpHelper(widget.client);
    final drives = await helper.listDrives();
    if (!mounted) return;

    setState(() {
      _availableDrives = drives;
      if (widget.initialPath == null && drives.isNotEmpty) {
        _currentPath = '${drives.first}:/';
      }
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);

    try {
      final helper = SftpHelper(widget.client);
      final out = await helper.listDirWithType(_currentPath);

      if (_currentPath != '.' && _currentPath != '/') {
        out.insert(0, <String, dynamic>{'name': '..', 'isDirectory': true});
      }

      if (!mounted) return;
      setState(() {
        _entries = out;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to list directory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateUp() async {
    final lastSlash = _currentPath.lastIndexOf('/');
    if (lastSlash <= 0) {
      setState(() => _currentPath = lastSlash == 0 ? '/' : '.');
    } else {
      setState(() => _currentPath = _currentPath.substring(0, lastSlash));
    }
    await _refresh();
  }

  Future<void> _enterDirectory(String name) async {
    setState(() {
      _currentPath = (_currentPath == '.' || _currentPath == '/')
          ? name
          : '$_currentPath/$name';
    });
    await _refresh();
  }

  void _selectCurrentDirectory() {
    Navigator.pop(context, _currentPath);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Project Directory'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _currentPath,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            if (_availableDrives.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableDrives.length,
                  itemBuilder: (context, idx) {
                    final drive = _availableDrives[idx];
                    final isSelected = _currentPath.startsWith('$drive:');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$drive:'),
                        selected: isSelected,
                        onSelected: (_) async {
                          setState(() => _currentPath = '$drive:/');
                          await _refresh();
                        },
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, idx) {
                        final item = _entries[idx];
                        final name = item['name'] as String;
                        final isDir = item['isDirectory'] as bool? ?? false;

                        if (!isDir) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(name),
                            enabled: false,
                          );
                        }

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder),
                          title: Text(name),
                          onTap: () async {
                            if (name == '..') {
                              await _navigateUp();
                            } else {
                              await _enterDirectory(name);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectCurrentDirectory,
          child: const Text('Select'),
        ),
      ],
    );
  }
}

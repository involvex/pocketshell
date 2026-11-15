import 'package:material_ui/material_ui.dart';

import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/utils/sftp_mode_utils.dart';

/// Bottom sheet to view and apply Unix permission bits on a remote SFTP entry.
Future<void> showSftpPermissionsSheet({
  required BuildContext context,
  required RemoteFsEntry entry,
  required int? initialMode,
  required Future<bool> Function(int mode, bool recursive) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return _SftpPermissionsSheet(
        entry: entry,
        initialMode: initialMode ?? 33188,
        onApply: onApply,
      );
    },
  );
}

class _SftpPermissionsSheet extends StatefulWidget {
  const _SftpPermissionsSheet({
    required this.entry,
    required this.initialMode,
    required this.onApply,
  });

  final RemoteFsEntry entry;
  final int initialMode;
  final Future<bool> Function(int mode, bool recursive) onApply;

  @override
  State<_SftpPermissionsSheet> createState() => _SftpPermissionsSheetState();
}

class _SftpPermissionsSheetState extends State<_SftpPermissionsSheet> {
  late int _mode;
  late final TextEditingController _octalController;
  bool _recursive = false;
  bool _applying = false;

  static const List<String> _roleLabels = <String>['Owner', 'Group', 'Other'];
  static const List<String> _permLabels = <String>['Read', 'Write', 'Execute'];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _octalController = TextEditingController(
      text: formatSftpPermissionOctal(_mode),
    );
  }

  @override
  void dispose() {
    _octalController.dispose();
    super.dispose();
  }

  void _syncOctalField() {
    _octalController.text = formatSftpPermissionOctal(_mode);
  }

  void _applyOctalInput(String value) {
    final int? parsed = parseSftpOctalMode(value);
    if (parsed == null) {
      return;
    }
    final int typeBits = _mode & ~kSftpModePermissionMask;
    setState(() {
      _mode = typeBits | (parsed & kSftpModePermissionMask);
      _syncOctalField();
    });
  }

  void _togglePermission(int role, int perm, bool enabled) {
    final int index = role * 3 + perm;
    setState(() {
      _mode = setSftpModePermission(_mode, index, enabled);
      _syncOctalField();
    });
  }

  Future<void> _submit() async {
    setState(() => _applying = true);
    final bool ok = await widget.onApply(_mode, _recursive);
    if (!mounted) {
      return;
    }
    setState(() => _applying = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showRecursive = widget.entry.isDirectory;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Permissions — ${widget.entry.name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _octalController,
              decoration: const InputDecoration(
                labelText: 'Octal mode',
                border: OutlineInputBorder(),
                helperText: 'Permission bits, e.g. 644 or 755',
              ),
              keyboardType: TextInputType.number,
              onChanged: _applyOctalInput,
              onSubmitted: _applyOctalInput,
            ),
            const SizedBox(height: 12),
            for (var role = 0; role < 3; role++) ...<Widget>[
              Text(_roleLabels[role], style: theme.textTheme.titleSmall),
              for (var perm = 0; perm < 3; perm++)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_permLabels[perm]),
                  value: sftpModeHasPermission(_mode, role * 3 + perm),
                  onChanged: (bool? value) {
                    if (value == null) {
                      return;
                    }
                    _togglePermission(role, perm, value);
                  },
                ),
            ],
            if (showRecursive)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Apply to contents recursively'),
                value: _recursive,
                onChanged: _applying
                    ? null
                    : (bool value) => setState(() => _recursive = value),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _applying ? null : _submit,
              child: _applying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
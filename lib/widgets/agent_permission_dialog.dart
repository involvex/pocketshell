import 'package:flutter/material.dart';

import '../models/agent_permission_request.dart';

class AgentPermissionDialog extends StatefulWidget {
  const AgentPermissionDialog({
    required this.request,
    required this.onRespond,
    required this.onDismiss,
    super.key,
  });

  final AgentPermissionRequest request;
  final Future<void> Function(String response, bool remember) onRespond;
  final VoidCallback onDismiss;

  @override
  State<AgentPermissionDialog> createState() => _AgentPermissionDialogState();
}

class _AgentPermissionDialogState extends State<AgentPermissionDialog> {
  bool _remember = false;
  bool _isResponding = false;

  Future<void> _respond(String response) async {
    setState(() => _isResponding = true);
    try {
      await widget.onRespond(response, _remember);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission response failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permission Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.request.message),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remember this choice'),
            value: _remember,
            onChanged: _isResponding
                ? null
                : (value) => setState(() => _remember = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isResponding
              ? null
              : () {
                  widget.onDismiss();
                  Navigator.of(context).pop();
                },
          child: const Text('Dismiss'),
        ),
        OutlinedButton(
          onPressed: _isResponding ? null : () => _respond('deny'),
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: _isResponding ? null : () => _respond('allow'),
          child: _isResponding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Allow'),
        ),
      ],
    );
  }
}

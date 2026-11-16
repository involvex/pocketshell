import 'package:dartssh2/dartssh2.dart';
import 'package:material_ui/material_ui.dart';

/// Collects answers for an SSH keyboard-interactive ([SSHUserInfoRequest]) prompt.
///
/// Returns `null` when the user cancels so dartssh2 can skip the method or fail auth.
Future<List<String>?> showKeyboardInteractiveDialog(
  BuildContext context,
  SSHUserInfoRequest request,
) async {
  if (request.prompts.isEmpty) {
    return <String>[];
  }

  return showDialog<List<String>?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _KeyboardInteractiveDialog(request: request);
    },
  );
}

class _KeyboardInteractiveDialog extends StatefulWidget {
  const _KeyboardInteractiveDialog({required this.request});

  final SSHUserInfoRequest request;

  @override
  State<_KeyboardInteractiveDialog> createState() =>
      _KeyboardInteractiveDialogState();
}

class _KeyboardInteractiveDialogState extends State<_KeyboardInteractiveDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.request.prompts.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _controllers.map((c) => c.text).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final title = request.name.trim().isEmpty
        ? 'Authentication required'
        : request.name.trim();
    final instruction = request.instruction.trim();

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (instruction.isNotEmpty) ...<Widget>[
              Text(instruction),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < request.prompts.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              TextField(
                controller: _controllers[i],
                autofocus: i == 0,
                obscureText: !request.prompts[i].echo,
                decoration: InputDecoration(
                  labelText: request.prompts[i].promptText.trim().isEmpty
                      ? 'Response'
                      : request.prompts[i].promptText.trim(),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: i == request.prompts.length - 1
                    ? (_) => _submit()
                    : null,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../services/ai_gateway_service.dart';
import '../utils/terminal_context.dart';
import '../utils/terminal_enter_mapping.dart';

class AiCommandButton extends StatelessWidget {
  const AiCommandButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () => _showGenerateDialog(context),
        borderRadius: BorderRadius.circular(0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.purple.shade800,
            borderRadius: BorderRadius.circular(0.25),
            border: Border.all(color: Colors.purple.shade300),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'AI',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 7,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 2),
              Flexible(
                child: Text(
                  'Generate command',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGenerateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _AiCommandDialog(),
    );
  }
}

class _AiCommandDialog extends StatefulWidget {
  const _AiCommandDialog();

  @override
  State<_AiCommandDialog> createState() => _AiCommandDialogState();
}

class _AiCommandDialogState extends State<_AiCommandDialog> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  final CancelToken _cancelToken = CancelToken();
  StreamSubscription<String>? _streamSubscription;
  bool _isGenerating = false;
  bool _includeTerminalContext = true;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    _resultController.addListener(_onResultChanged);
  }

  void _onResultChanged() {
    final hasResult = _resultController.text.trim().isNotEmpty;
    if (hasResult != _hasResult) {
      setState(() => _hasResult = hasResult);
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _cancelToken.cancel();
    _resultController
      ..removeListener(_onResultChanged)
      ..dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final settings = context.read<SettingsProvider>();
    final ssh = context.read<SSHProvider>();
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    await _streamSubscription?.cancel();
    _resultController.clear();

    final terminalContext = _includeTerminalContext
        ? ssh.getActiveTerminalContext(
            lineCount: kDefaultTerminalContextLines,
          )
        : null;

    setState(() => _isGenerating = true);
    try {
      final stream = AiGatewayService.streamCommand(
        provider: settings.aiProvider,
        apiKey: settings.activeAiApiKey,
        model: settings.activeAiModel,
        userPrompt: prompt,
        terminalContext: terminalContext,
        cancelToken: _cancelToken,
      );

      _streamSubscription = stream.listen(
        (chunk) {
          _resultController.text += chunk;
          _resultController.selection = TextSelection.collapsed(
            offset: _resultController.text.length,
          );
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
          if (_resultController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI returned an empty command'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendToTerminal() async {
    final command = _resultController.text.trim();
    if (command.isEmpty) return;

    final ssh = context.read<SSHProvider>();
    ssh.sendString(withEnterSuffix(command, ssh.terminalEnterSends));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copyCommand() async {
    final command = _resultController.text.trim();
    if (command.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: command));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Command copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return AlertDialog(
      title: const Text('AI Command Generator'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Provider: ${settings.aiProvider.displayName} · '
              'Model: ${settings.activeAiModel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Describe the command',
                hintText: 'e.g. list running docker containers',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
              enabled: !_isGenerating,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Include last $kDefaultTerminalContextLines lines of terminal '
                'output',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _includeTerminalContext,
              onChanged: _isGenerating
                  ? null
                  : (value) {
                      setState(() {
                        _includeTerminalContext = value ?? true;
                      });
                    },
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _resultController,
              decoration: InputDecoration(
                labelText: 'Generated command',
                border: const OutlineInputBorder(),
                suffixIcon: _isGenerating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              minLines: 2,
              maxLines: 6,
              readOnly: _isGenerating,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: !_hasResult || _isGenerating ? null : _copyCommand,
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: _isGenerating ? null : _generate,
          child: const Text('Generate'),
        ),
        FilledButton(
          onPressed: !_hasResult || _isGenerating ? null : _sendToTerminal,
          child: const Text('Send to terminal'),
        ),
      ],
    );
  }
}

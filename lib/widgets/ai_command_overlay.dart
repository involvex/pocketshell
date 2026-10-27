import 'dart:async';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/models/ai_provider.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/ai_gateway_service.dart';
import 'package:ssh_app/utils/terminal_clipboard.dart';
import 'package:ssh_app/utils/terminal_context.dart';
import 'package:ssh_app/utils/terminal_enter_mapping.dart';

/// Termius-style top overlay for converting natural language to a shell command.
class AiCommandOverlay extends StatefulWidget {
  const AiCommandOverlay({
    required this.onClose,
    super.key,
  });

  final VoidCallback onClose;

  @override
  State<AiCommandOverlay> createState() => _AiCommandOverlayState();
}

class _AiCommandOverlayState extends State<AiCommandOverlay> {
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
    if (prompt.isEmpty) {
      return;
    }

    if (settings.activeAiApiKey.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure an AI API key in Settings first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
          if (!mounted) {
            return;
          }
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        },
        onDone: () {
          if (!mounted) {
            return;
          }
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
      if (!mounted) {
        return;
      }
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
    if (command.isEmpty) {
      return;
    }

    final ssh = context.read<SSHProvider>();
    ssh.sendString(withEnterSuffix(command, ssh.terminalEnterSends));
    widget.onClose();
  }

  Future<void> _copyCommand() async {
    final command = _resultController.text.trim();
    if (command.isEmpty) {
      return;
    }
    await TerminalClipboard.copyText(command);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Command copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Material(
      elevation: 4,
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Convert text to command with AI',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close',
                  onPressed: _isGenerating ? null : widget.onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            Text(
              '${settings.aiProvider.displayName} · ${settings.activeAiModel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    enabled: !_isGenerating,
                    decoration: InputDecoration(
                      hintText: 'example: monitor disk usage',
                      filled: true,
                      fillColor: colors.primary.withValues(alpha: 0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _isGenerating ? null : _generate,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _isGenerating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              color: colors.onPrimary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Include last $kDefaultTerminalContextLines lines of output',
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
            if (_hasResult || _isGenerating) ...[
              TextField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: 'Generated command',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 4,
                readOnly: _isGenerating,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed:
                        !_hasResult || _isGenerating ? null : _copyCommand,
                    child: const Text('Copy'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed:
                        !_hasResult || _isGenerating ? null : _sendToTerminal,
                    child: const Text('Send to terminal'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

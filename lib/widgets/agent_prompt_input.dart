import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:opencode_api/opencode_api.dart';

import '../models/agent_model_option.dart';
import '../models/agent_prompt_attachment.dart';
import '../utils/agent_prompt_utils.dart';

typedef AgentPromptSubmitCallback = void Function(AgentPromptSubmission submission);

typedef AgentRemoteFilePicker = Future<AgentPromptAttachment?> Function();

class AgentPromptInput extends StatefulWidget {
  const AgentPromptInput({
    required this.commands,
    required this.agents,
    required this.models,
    required this.enabled,
    required this.isSending,
    required this.onSubmit,
    this.onPickRemoteFile,
    this.contextChips = const <Widget>[],
    super.key,
  });

  final List<Command> commands;
  final List<Agent> agents;
  final List<AgentModelOption> models;
  final bool enabled;
  final bool isSending;
  final AgentPromptSubmitCallback onSubmit;
  final AgentRemoteFilePicker? onPickRemoteFile;
  final List<Widget> contextChips;

  @override
  State<AgentPromptInput> createState() => _AgentPromptInputState();
}

class _AgentPromptInputState extends State<AgentPromptInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedSuggestionIndex = 0;
  bool _showSuggestions = false;
  final List<AgentPromptAttachment> _attachments = <AgentPromptAttachment>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  List<PromptSuggestion> get _suggestions => buildPromptSuggestions(
        input: _controller.text,
        commands: widget.commands,
        agents: widget.agents,
        models: widget.models,
      );

  int _maxLinesForViewport(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    const lineHeight = 22.0;
    final maxFromViewport = (height * 0.25 / lineHeight).floor();
    return maxFromViewport.clamp(1, 12);
  }

  double _suggestionMaxHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height * 0.2).clamp(80, 160);
  }

  void _updateSuggestions() {
    final visible = isSlashCommand(_controller.text) && _suggestions.isNotEmpty;
    setState(() {
      _showSuggestions = visible;
      _selectedSuggestionIndex = 0;
    });
  }

  void _applySuggestion(PromptSuggestion suggestion) {
    _controller.text = suggestion.insertText;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {
      _showSuggestions = false;
      _selectedSuggestionIndex = 0;
    });
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _pickLocalFile() async {
    if (!widget.enabled || widget.isSending) return;
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;

    final file = result.first;
    final path = file.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    setState(() {
      _attachments.add(
        AgentPromptAttachment.localBytes(filename: file.name, bytes: bytes),
      );
    });
  }

  Future<void> _pickRemoteFile() async {
    if (!widget.enabled || widget.isSending) return;
    final picker = widget.onPickRemoteFile;
    if (picker == null) return;
    final attachment = await picker();
    if (attachment == null || !mounted) return;
    setState(() => _attachments.add(attachment));
  }

  Future<void> _showAttachMenu() async {
    final hasRemote = widget.onPickRemoteFile != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Local file'),
                onTap: () => Navigator.pop(context, 'local'),
              ),
              if (hasRemote)
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Remote file (SFTP)'),
                  onTap: () => Navigator.pop(context, 'remote'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'local') {
      await _pickLocalFile();
    } else if (choice == 'remote') {
      await _pickRemoteFile();
    }
  }

  void _submit() {
    if (!widget.enabled || widget.isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    final attachments = List<AgentPromptAttachment>.from(_attachments);
    _controller.clear();
    setState(() {
      _attachments.clear();
      _showSuggestions = false;
      _selectedSuggestionIndex = 0;
    });
    widget.onSubmit(AgentPromptSubmission(text: text, attachments: attachments));
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (event.logicalKey == LogicalKeyboardKey.enter && shift) {
      final value = _controller.text;
      final selection = _controller.selection;
      final insertAt = selection.baseOffset;
      final updated = '${value.substring(0, insertAt)}\n'
          '${value.substring(insertAt)}';
      _controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: insertAt + 1),
      );
      return KeyEventResult.handled;
    }

    if (_showSuggestions) {
      final suggestions = _suggestions;
      if (suggestions.isEmpty) return KeyEventResult.ignored;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedSuggestionIndex =
              (_selectedSuggestionIndex + 1) % suggestions.length;
        });
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedSuggestionIndex =
              (_selectedSuggestionIndex - 1 + suggestions.length) %
                  suggestions.length;
        });
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showSuggestions = false);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.tab ||
          (event.logicalKey == LogicalKeyboardKey.enter &&
              suggestions.isNotEmpty)) {
        _applySuggestion(suggestions[_selectedSuggestionIndex]);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        widget.enabled &&
        !widget.isSending) {
      _submit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final canSend = widget.enabled && !widget.isSending;
    final maxLines = _maxLinesForViewport(context);
    final slashMode = isSlashCommand(_controller.text);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.contextChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: widget.contextChips,
              ),
            ),
          if (_attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _attachments.length; i++)
                    InputChip(
                      label: Text(
                        _attachments[i].displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: canSend ? () => _removeAttachment(i) : null,
                    ),
                ],
              ),
            ),
          if (_showSuggestions && suggestions.isNotEmpty)
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _suggestionMaxHeight(context),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length.clamp(0, 6),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    final selected = index == _selectedSuggestionIndex;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      title: Text(suggestion.label),
                      subtitle: suggestion.description == null
                          ? null
                          : Text(
                              suggestion.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _applySuggestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: slashMode ? 'Attachments disabled for commands' : 'Attach file',
                  onPressed: canSend && !slashMode ? _showAttachMenu : null,
                  icon: const Icon(Icons.attach_file, size: 20),
                ),
              ),
              Expanded(
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Prompt or /command · Shift+Enter newline',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    minLines: 1,
                    maxLines: maxLines,
                    enabled: canSend,
                    onChanged: (_) => _updateSuggestions(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                height: 40,
                child: FilledButton(
                  onPressed: canSend ? _submit : null,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                  ),
                  child: widget.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
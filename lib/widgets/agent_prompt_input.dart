import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencode_api/opencode_api.dart';

import '../models/agent_model_option.dart';
import '../utils/agent_prompt_utils.dart';

class AgentPromptInput extends StatefulWidget {
  const AgentPromptInput({
    required this.commands,
    required this.agents,
    required this.models,
    required this.enabled,
    required this.isSending,
    required this.onSubmit,
    super.key,
  });

  final List<Command> commands;
  final List<Agent> agents;
  final List<AgentModelOption> models;
  final bool enabled;
  final bool isSending;
  final ValueChanged<String> onSubmit;

  @override
  State<AgentPromptInput> createState() => _AgentPromptInputState();
}

class _AgentPromptInputState extends State<AgentPromptInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedSuggestionIndex = 0;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<PromptSuggestion> get _suggestions => buildPromptSuggestions(
        input: _controller.text,
        commands: widget.commands,
        agents: widget.agents,
        models: widget.models,
      );

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

  void _submit() {
    if (!widget.enabled || widget.isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _showSuggestions = false;
      _selectedSuggestionIndex = 0;
    });
    widget.onSubmit(text);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_showSuggestions) {
      return KeyEventResult.ignored;
    }

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
            _showSuggestions &&
            suggestions.isNotEmpty)) {
      _applySuggestion(suggestions[_selectedSuggestionIndex]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final canSend = widget.enabled && !widget.isSending;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSuggestions && suggestions.isNotEmpty)
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
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
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText:
                          'Send a prompt or /command (e.g. /help, /agent build)',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    enabled: canSend,
                    onChanged: (_) => _updateSuggestions(),
                    onSubmitted: canSend ? (_) => _submit() : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canSend ? _submit : null,
                child: widget.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

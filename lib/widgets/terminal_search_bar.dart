import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'package:ssh_app/utils/terminal_search.dart';

/// Manages search hits and their in-terminal highlights for one session.
///
/// Highlights use stable [CellAnchor]s, so they track buffer mutations while
/// the bar is open. Matches are recomputed on every navigation step to stay
/// fresh as new output arrives. Highlight count is capped for performance;
/// the match list itself can be longer.
class TerminalSearchSession {
  TerminalSearchSession({
    required this.terminal,
    required this.controller,
  });

  final Terminal terminal;
  final TerminalController controller;

  static const int maxMatches = 500;
  static const int maxHighlightedMatches = 200;

  List<TerminalSearchMatch> matches = const <TerminalSearchMatch>[];
  int currentIndex = 0;
  String query = '';
  bool caseSensitive = false;

  final List<TerminalHighlight> _highlights = <TerminalHighlight>[];
  final List<CellAnchor> _anchors = <CellAnchor>[];

  bool get hasResults => matches.isNotEmpty;

  TerminalSearchMatch? get currentMatch =>
      hasResults ? matches[currentIndex % matches.length] : null;

  void search(String value, {bool? caseSensitive}) {
    query = value;
    if (caseSensitive != null) {
      this.caseSensitive = caseSensitive;
    }
    _refresh();
    if (hasResults) {
      _scrollToCurrent();
    }
  }

  void next() {
    _refresh();
    if (hasResults) {
      currentIndex = (currentIndex + 1) % matches.length;
      _applyHighlights();
      _scrollToCurrent();
    }
  }

  void previous() {
    _refresh();
    if (hasResults) {
      currentIndex = (currentIndex - 1 + matches.length) % matches.length;
      _applyHighlights();
      _scrollToCurrent();
    }
  }

  /// Scrolls the viewport so the current match sits inside the visible
  /// scrollback window. Uses the controller's selection API, which xterm's
  /// [TerminalView] scrolls to.
  void _scrollToCurrent() {
    final TerminalSearchMatch match = currentMatch!;
    if (match.line < 0 || match.line >= terminal.buffer.height) {
      return;
    }
    final BufferLine line = terminal.buffer.lines[match.line];
    final CellAnchor start = line.createAnchor(match.startX);
    final CellAnchor end = line.createAnchor(match.endX);
    try {
      controller.setSelection(start, end);
    } finally {
      start.dispose();
      end.dispose();
    }
  }

  void _refresh() {
    clearHighlights();
    matches = findTerminalMatches(
      terminal,
      query,
      caseSensitive: caseSensitive,
      maxMatches: maxMatches,
    );
    if (matches.isNotEmpty) {
      currentIndex = currentIndex % matches.length;
    } else {
      currentIndex = 0;
    }
    _applyHighlights();
  }

  void _applyHighlights() {
    clearHighlights();
    final int count = matches.length > maxHighlightedMatches
        ? maxHighlightedMatches
        : matches.length;
    for (var i = 0; i < count; i++) {
      final TerminalSearchMatch match = matches[i];
      if (match.line < 0 || match.line >= terminal.buffer.height) {
        continue;
      }
      final BufferLine line = terminal.buffer.lines[match.line];
      final CellAnchor start = line.createAnchor(match.startX);
      final CellAnchor end = line.createAnchor(match.endX);
      _anchors.add(start);
      _anchors.add(end);
      _highlights.add(
        controller.highlight(
          p1: start,
          p2: end,
          color: i == currentIndex % matches.length
              ? Colors.orange.withValues(alpha: 0.55)
              : Colors.yellow.withValues(alpha: 0.30),
        ),
      );
    }
  }

  void clearHighlights() {
    for (final TerminalHighlight highlight in _highlights) {
      highlight.dispose();
    }
    _highlights.clear();
    for (final CellAnchor anchor in _anchors) {
      anchor.dispose();
    }
    _anchors.clear();
  }

  void dispose() {
    clearHighlights();
  }
}

/// Search bar overlay for finding text in the terminal scrollback.
/// Matches are highlighted in-terminal; up/down cycles the active hit.
class TerminalSearchBar extends StatefulWidget {
  const TerminalSearchBar({
    required this.terminal,
    required this.controller,
    required this.onClose,
    super.key,
  });

  final Terminal terminal;
  final TerminalController controller;
  final VoidCallback onClose;

  @override
  State<TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<TerminalSearchBar> {
  late final TextEditingController _queryController;
  late final TerminalSearchSession _session;
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _session = TerminalSearchSession(
      terminal: widget.terminal,
      controller: widget.controller,
    );
  }

  @override
  void dispose() {
    _session.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _session.search(_queryController.text, caseSensitive: _caseSensitive);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String counter = _session.query.isEmpty
        ? ''
        : _session.hasResults
            ? '${_session.currentIndex + 1}/${_session.matches.length}'
            : '0/0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Find in terminal',
                isDense: true,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              onChanged: (_) => _runSearch(),
              onSubmitted: (_) => setState(_session.next),
            ),
          ),
          if (counter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                counter,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                ),
              ),
            ),
          IconButton(
            icon: const Text(
              'Aa',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            tooltip:
                _caseSensitive ? 'Case sensitive: on' : 'Case sensitive: off',
            color: _caseSensitive ? Colors.tealAccent : Colors.white70,
            onPressed: () {
              setState(() {
                _caseSensitive = !_caseSensitive;
                _runSearch();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            onPressed:
                _session.hasResults ? () => setState(_session.previous) : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            onPressed:
                _session.hasResults ? () => setState(_session.next) : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close search',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}

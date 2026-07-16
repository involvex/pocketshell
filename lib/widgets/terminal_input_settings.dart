import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/terminal_enter_mapping.dart';
import '../utils/terminal_themes.dart';

/// Enter mapping, mouse taps, and terminal color theme controls.
class TerminalInputSettings extends StatelessWidget {
  const TerminalInputSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter sends',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TerminalEnterSends>(
                    segments: const [
                      ButtonSegment(
                        value: TerminalEnterSends.cr,
                        label: Text('CR'),
                      ),
                      ButtonSegment(
                        value: TerminalEnterSends.lf,
                        label: Text('LF'),
                      ),
                      ButtonSegment(
                        value: TerminalEnterSends.crlf,
                        label: Text('CRLF'),
                      ),
                      ButtonSegment(
                        value: TerminalEnterSends.ctrlM,
                        label: Text('Ctrl+M'),
                      ),
                    ],
                    selected: {settings.terminalEnterSends},
                    onSelectionChanged: (selection) {
                      settings.setTerminalEnterSends(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Character(s) sent when you press Enter in the terminal.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.mouse_outlined),
                  title: const Text('Send mouse taps'),
                  subtitle: const Text(
                    'Forward terminal taps as mouse clicks when apps '
                    'enable mouse tracking. Long-press sends Shift+F10 '
                    '(context menu).',
                  ),
                  value: settings.sendMouseTaps,
                  onChanged: settings.setSendMouseTaps,
                ),
                const Divider(height: 32),
                const Text(
                  'Terminal color theme',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TerminalColorTheme.values.map((theme) {
                    final selected = settings.terminalColorTheme == theme;
                    return ChoiceChip(
                      label: Text(theme.displayName),
                      selected: selected,
                      onSelected: (value) {
                        if (value) {
                          settings.setTerminalColorTheme(theme);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

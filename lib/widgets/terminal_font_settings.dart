import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/terminal_style_builder.dart';

class TerminalFontSettings extends StatelessWidget {
  const TerminalFontSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final previewStyle = TerminalStyleBuilder.buildTextStyle(settings);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Font Size'),
                    Text('${settings.terminalFontSize.toInt()}'),
                  ],
                ),
                Slider(
                  value: settings.terminalFontSize,
                  min: 6,
                  max: 24,
                  divisions: 18,
                  onChanged: settings.setTerminalFontSize,
                ),
                const SizedBox(height: 8),
                const Text('Font Family'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TerminalFontFamily.values.map((family) {
                    final selected = settings.terminalFontFamily == family;
                    return ChoiceChip(
                      label: Text(switch (family) {
                        TerminalFontFamily.monospace => 'Monospace',
                        TerminalFontFamily.courierNew => 'Courier New',
                        TerminalFontFamily.consolas => 'Consolas',
                        TerminalFontFamily.menlo => 'Menlo',
                        TerminalFontFamily.jetBrainsMono => 'JetBrains Mono',
                        TerminalFontFamily.firaCode => 'Fira Code',
                        TerminalFontFamily.spaceMono => 'Space Mono',
                        TerminalFontFamily.sourceCodePro => 'Source Code Pro',
                      }),
                      selected: selected,
                      onSelected: (value) {
                        if (value) settings.setTerminalFontFamily(family);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Font Weight'),
                const SizedBox(height: 8),
                SegmentedButton<TerminalFontWeight>(
                  segments: const [
                    ButtonSegment(
                      value: TerminalFontWeight.normal,
                      label: Text('Normal'),
                    ),
                    ButtonSegment(
                      value: TerminalFontWeight.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment(
                      value: TerminalFontWeight.semiBold,
                      label: Text('SemiBold'),
                    ),
                    ButtonSegment(
                      value: TerminalFontWeight.bold,
                      label: Text('Bold'),
                    ),
                  ],
                  selected: {settings.terminalFontWeight},
                  onSelectionChanged: (selection) {
                    settings.setTerminalFontWeight(selection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Font Style'),
                const SizedBox(height: 8),
                SegmentedButton<TerminalFontStyle>(
                  segments: const [
                    ButtonSegment(
                      value: TerminalFontStyle.normal,
                      label: Text('Normal'),
                    ),
                    ButtonSegment(
                      value: TerminalFontStyle.italic,
                      label: Text('Italic'),
                    ),
                  ],
                  selected: {settings.terminalFontStyle},
                  onSelectionChanged: (selection) {
                    settings.setTerminalFontStyle(selection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Preview'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Text(
                    r'abc 123 $ ssh user@host',
                    style: previewStyle.copyWith(color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

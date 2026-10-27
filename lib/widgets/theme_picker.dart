import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme Preset',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AppTheme>(
                segments: const [
                  ButtonSegment<AppTheme>(
                    value: AppTheme.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_suggest),
                  ),
                  ButtonSegment<AppTheme>(
                    value: AppTheme.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment<AppTheme>(
                    value: AppTheme.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment<AppTheme>(
                    value: AppTheme.hacker,
                    label: Text('Hacker'),
                    icon: Icon(Icons.terminal),
                  ),
                ], // prefer_const_literals_to_create_immutables fix
                selected: {settings.appTheme},
                onSelectionChanged: (Set<AppTheme> newSelection) {
                  settings.setAppTheme(newSelection.first);
                },
              ),
            ),
            if (settings.appTheme != AppTheme.hacker) ...[
              const SizedBox(height: 24),
              const Text(
                'Accent Color',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ColorOption(
                      color: Colors.blue, current: settings.accentColor),
                  _ColorOption(
                      color: Colors.green, current: settings.accentColor),
                  _ColorOption(
                      color: Colors.purple, current: settings.accentColor),
                  _ColorOption(
                      color: Colors.orange, current: settings.accentColor),
                  _ColorOption(
                      color: Colors.red, current: settings.accentColor),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final Color current;

  const _ColorOption({required this.color, required this.current});

  @override
  Widget build(BuildContext context) {
    final isSelected = color.toARGB32() == current.toARGB32();
    return GestureDetector(
      onTap: () {
        context.read<SettingsProvider>().setAccentColor(color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/models/home_toolbar_action.dart';
import 'package:ssh_app/providers/settings_provider.dart';

/// Toggles which home AppBar actions are pinned vs overflow-only.
class ToolbarActionSettings extends StatelessWidget {
  const ToolbarActionSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (BuildContext context, SettingsProvider settings, Widget? _) {
        return Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Toolbar shortcuts'),
                subtitle: Text(
                  'Pinned actions show as icons in the top bar; '
                  'others stay in the More menu',
                ),
              ),
              const Divider(height: 1),
              for (final HomeToolbarAction action
                  in HomeToolbarActionX.displayOrder) ...[
                SwitchListTile(
                  secondary: Icon(action.icon),
                  title: Text(action.label),
                  value: settings.isToolbarActionPinned(action),
                  onChanged: (bool value) {
                    // ignore: unawaited_futures
                    settings.setToolbarActionPinned(action, value);
                  },
                ),
                if (action != HomeToolbarActionX.displayOrder.last)
                  const Divider(height: 1, indent: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

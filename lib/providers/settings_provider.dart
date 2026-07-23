import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../models/home_toolbar_action.dart';
import '../models/keyboard_shortcut.dart';
import '../services/config_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/terminal_enter_mapping.dart';
import '../utils/terminal_themes.dart';

enum AppTheme { system, light, dark, hacker }

enum TerminalFontFamily {
  monospace,
  courierNew,
  consolas,
  menlo,
  jetBrainsMono,
  firaCode,
  spaceMono,
  sourceCodePro,
}

enum TerminalFontWeight {
  normal,
  medium,
  semiBold,
  bold,
}

enum TerminalFontStyle {
  normal,
  italic,
}

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  AppTheme _appTheme = AppTheme.dark;
  Color _accentColor = Colors.blue;
  List<KeyboardShortcut> _shortcuts = [];
  bool _isLoaded = false;
  double _terminalFontSize = 12.0;
  bool _showMobileShortcutBar = false;
  int _defaultAgentPort = 5000;
  TerminalFontFamily _terminalFontFamily = TerminalFontFamily.monospace;
  TerminalFontWeight _terminalFontWeight = TerminalFontWeight.normal;
  TerminalFontStyle _terminalFontStyle = TerminalFontStyle.normal;
  TerminalEnterSends _terminalEnterSends = TerminalEnterSends.cr;
  bool _sendMouseTaps = true;
  TerminalColorTheme _terminalColorTheme = TerminalColorTheme.standard;
  AiProvider _aiProvider = AiProvider.opencodeZen;
  String _opencodeZenApiKey = '';
  String _kiloApiKey = '';
  String _opencodeZenModel = AiProviderDefaults.opencodeZenModel;
  String _kiloModel = AiProviderDefaults.kiloModel;
  Set<HomeToolbarAction> _pinnedToolbarActions =
      HomeToolbarActionX.defaultPinned;

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  Color get accentColor => _accentColor;
  List<KeyboardShortcut> get shortcuts => _shortcuts;
  bool get isLoaded => _isLoaded;
  double get terminalFontSize => _terminalFontSize;
  bool get showMobileShortcutBar => _showMobileShortcutBar;
  int get defaultAgentPort => _defaultAgentPort;
  TerminalFontFamily get terminalFontFamily => _terminalFontFamily;
  TerminalFontWeight get terminalFontWeight => _terminalFontWeight;
  TerminalFontStyle get terminalFontStyle => _terminalFontStyle;
  TerminalEnterSends get terminalEnterSends => _terminalEnterSends;
  bool get sendMouseTaps => _sendMouseTaps;
  TerminalColorTheme get terminalColorTheme => _terminalColorTheme;
  AiProvider get aiProvider => _aiProvider;
  String get opencodeZenApiKey => _opencodeZenApiKey;
  String get kiloApiKey => _kiloApiKey;
  String get opencodeZenModel => _opencodeZenModel;
  String get kiloModel => _kiloModel;
  Set<HomeToolbarAction> get pinnedToolbarActions => _pinnedToolbarActions;

  bool isToolbarActionPinned(HomeToolbarAction action) =>
      _pinnedToolbarActions.contains(action);

  String get activeAiApiKey => switch (_aiProvider) {
        AiProvider.opencodeZen => _opencodeZenApiKey,
        AiProvider.kiloGateway => _kiloApiKey,
      };

  String get activeAiModel => switch (_aiProvider) {
        AiProvider.opencodeZen => _opencodeZenModel,
        AiProvider.kiloGateway => _kiloModel,
      };

  List<KeyboardShortcut> getShortcutsByRow(int row) {
    return _shortcuts.where((s) => s.row == row).toList();
  }

  int get maxRow => _shortcuts.isEmpty
      ? 0
      : _shortcuts.map((s) => s.row).reduce((a, b) => a > b ? a : b);

  Future<void> loadSettings() async {
    final settings = await ConfigService.getSettings();

    final themeStr = settings['appTheme'] as String? ?? 'dark';
    _appTheme = AppTheme.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppTheme.dark,
    );

    _themeMode = switch (_appTheme) {
      AppTheme.light => ThemeMode.light,
      AppTheme.dark => ThemeMode.dark,
      AppTheme.system => ThemeMode.system,
      AppTheme.hacker => ThemeMode.dark,
    };

    final accentColorStr = settings['accentColor'] as String? ?? 'blue';
    _accentColor = switch (accentColorStr) {
      'green' => Colors.green,
      'purple' => Colors.purple,
      'orange' => Colors.orange,
      'red' => Colors.red,
      _ => Colors.blue,
    };

    final shortcutsData = settings['shortcuts'] as List<dynamic>?;
    if (shortcutsData != null && shortcutsData.isNotEmpty) {
      _shortcuts = shortcutsData
          .map((e) =>
              KeyboardShortcut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      _shortcuts = KeyboardShortcut.defaults;
    }

    final fontSizeVal = settings['terminalFontSize'];
    if (fontSizeVal != null) {
      _terminalFontSize = (fontSizeVal as num).toDouble();
    }

    _showMobileShortcutBar =
        settings['showMobileShortcutBar'] as bool? ?? false;

    final agentPortVal = settings['defaultAgentPort'];
    if (agentPortVal != null) {
      _defaultAgentPort = (agentPortVal as num).toInt();
    }

    _terminalFontFamily = _parseFontFamily(
      settings['terminalFontFamily'] as String? ?? 'monospace',
    );
    _terminalFontWeight = _parseFontWeight(
      settings['terminalFontWeight'] as String? ?? 'normal',
    );
    _terminalFontStyle = _parseFontStyle(
      settings['terminalFontStyle'] as String? ?? 'normal',
    );

    _terminalEnterSends = TerminalEnterSends.values.firstWhere(
      (e) => e.name == (settings['terminalEnterSends'] as String? ?? 'cr'),
      orElse: () => TerminalEnterSends.cr,
    );
    _sendMouseTaps = settings['sendMouseTaps'] as bool? ?? true;
    _terminalColorTheme = TerminalColorThemeX.fromStorage(
      settings['terminalColorTheme'] as String?,
    );

    _aiProvider = AiProvider.values.firstWhere(
      (e) => e.name == (settings['aiProvider'] as String? ?? 'opencodeZen'),
      orElse: () => AiProvider.opencodeZen,
    );

    if (await SecureStorageService.migrateApiKeysFromSettings(settings)) {
      await ConfigService.saveSettings(settings);
    }

    _opencodeZenApiKey = await SecureStorageService.readOpencodeZenApiKey();
    _kiloApiKey = await SecureStorageService.readKiloApiKey();
    _opencodeZenModel = settings['opencodeZenModel'] as String? ??
        AiProviderDefaults.opencodeZenModel;
    _kiloModel =
        settings['kiloModel'] as String? ?? AiProviderDefaults.kiloModel;

    _pinnedToolbarActions = _parsePinnedToolbarActions(
      settings['pinnedToolbarActions'] as List<dynamic>?,
    );

    _isLoaded = true;
    notifyListeners();
  }

  static TerminalFontFamily _parseFontFamily(String value) {
    return TerminalFontFamily.values.firstWhere(
      (e) => e.name == value || _fontFamilyStorageKey(e) == value,
      orElse: () => TerminalFontFamily.monospace,
    );
  }

  static String _fontFamilyStorageKey(TerminalFontFamily family) {
    return switch (family) {
      TerminalFontFamily.monospace => 'monospace',
      TerminalFontFamily.courierNew => 'courierNew',
      TerminalFontFamily.consolas => 'consolas',
      TerminalFontFamily.menlo => 'menlo',
      TerminalFontFamily.jetBrainsMono => 'jetBrainsMono',
      TerminalFontFamily.firaCode => 'firaCode',
      TerminalFontFamily.spaceMono => 'spaceMono',
      TerminalFontFamily.sourceCodePro => 'sourceCodePro',
    };
  }

  static TerminalFontWeight _parseFontWeight(String value) {
    return TerminalFontWeight.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TerminalFontWeight.normal,
    );
  }

  static TerminalFontStyle _parseFontStyle(String value) {
    return TerminalFontStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TerminalFontStyle.normal,
    );
  }

  static Set<HomeToolbarAction> _parsePinnedToolbarActions(
    List<dynamic>? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return HomeToolbarActionX.defaultPinned;
    }
    final Set<HomeToolbarAction> parsed = <HomeToolbarAction>{};
    for (final dynamic entry in raw) {
      final HomeToolbarAction? action =
          HomeToolbarActionX.fromStorageKey(entry as String);
      if (action != null) {
        parsed.add(action);
      }
    }
    return parsed.isEmpty ? HomeToolbarActionX.defaultPinned : parsed;
  }

  Future<void> setToolbarActionPinned(
    HomeToolbarAction action,
    bool pinned,
  ) async {
    if (pinned) {
      _pinnedToolbarActions = {..._pinnedToolbarActions, action};
    } else {
      _pinnedToolbarActions = _pinnedToolbarActions
          .where((HomeToolbarAction item) => item != action)
          .toSet();
    }
    await _saveSetting(
      'pinnedToolbarActions',
      _pinnedToolbarActions.map((HomeToolbarAction item) => item.name).toList(),
    );
    notifyListeners();
  }

  Future<void> setTerminalFontSize(double size) async {
    _terminalFontSize = size;
    await _saveSetting('terminalFontSize', size);
    notifyListeners();
  }

  Future<void> setShowMobileShortcutBar(bool value) async {
    _showMobileShortcutBar = value;
    await _saveSetting('showMobileShortcutBar', value);
    notifyListeners();
  }

  Future<void> setDefaultAgentPort(int port) async {
    _defaultAgentPort = port;
    await _saveSetting('defaultAgentPort', port);
    notifyListeners();
  }

  Future<void> setTerminalFontFamily(TerminalFontFamily family) async {
    _terminalFontFamily = family;
    await _saveSetting('terminalFontFamily', _fontFamilyStorageKey(family));
    notifyListeners();
  }

  Future<void> setTerminalFontWeight(TerminalFontWeight weight) async {
    _terminalFontWeight = weight;
    await _saveSetting('terminalFontWeight', weight.name);
    notifyListeners();
  }

  Future<void> setTerminalFontStyle(TerminalFontStyle style) async {
    _terminalFontStyle = style;
    await _saveSetting('terminalFontStyle', style.name);
    notifyListeners();
  }

  Future<void> setTerminalEnterSends(TerminalEnterSends value) async {
    _terminalEnterSends = value;
    await _saveSetting('terminalEnterSends', value.name);
    notifyListeners();
  }

  Future<void> setSendMouseTaps(bool value) async {
    _sendMouseTaps = value;
    await _saveSetting('sendMouseTaps', value);
    notifyListeners();
  }

  Future<void> setTerminalColorTheme(TerminalColorTheme theme) async {
    _terminalColorTheme = theme;
    await _saveSetting('terminalColorTheme', theme.name);
    notifyListeners();
  }

  Future<void> setAiProvider(AiProvider provider) async {
    _aiProvider = provider;
    await _saveSetting('aiProvider', provider.name);
    notifyListeners();
  }

  Future<void> setOpencodeZenApiKey(String value) async {
    _opencodeZenApiKey = value;
    await SecureStorageService.writeOpencodeZenApiKey(value);
    notifyListeners();
  }

  Future<void> setKiloApiKey(String value) async {
    _kiloApiKey = value;
    await SecureStorageService.writeKiloApiKey(value);
    notifyListeners();
  }

  Future<void> setOpencodeZenModel(String value) async {
    _opencodeZenModel = value;
    await _saveSetting('opencodeZenModel', value);
    notifyListeners();
  }

  Future<void> setKiloModel(String value) async {
    _kiloModel = value;
    await _saveSetting('kiloModel', value);
    notifyListeners();
  }

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    _themeMode = switch (theme) {
      AppTheme.light => ThemeMode.light,
      AppTheme.dark => ThemeMode.dark,
      AppTheme.system => ThemeMode.system,
      AppTheme.hacker => ThemeMode.dark,
    };
    await _saveSetting('appTheme', theme.name);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _appTheme = switch (mode) {
      ThemeMode.light => AppTheme.light,
      ThemeMode.dark => AppTheme.dark,
      ThemeMode.system => AppTheme.system,
    };
    await _saveSetting('appTheme', _appTheme.name);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final colorStr = switch (color) {
      final c when c == Colors.blue => 'blue',
      final c when c == Colors.green => 'green',
      final c when c == Colors.purple => 'purple',
      final c when c == Colors.orange => 'orange',
      final c when c == Colors.red => 'red',
      _ => 'blue',
    };
    await _saveSetting('accentColor', colorStr);
    notifyListeners();
  }

  Future<void> updateShortcuts(List<KeyboardShortcut> shortcuts) async {
    _shortcuts = shortcuts;
    await _saveSetting('shortcuts', shortcuts.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> resetShortcuts() async {
    _shortcuts = KeyboardShortcut.defaults;
    await _saveSetting('shortcuts', _shortcuts.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final settings = await ConfigService.getSettings();
    settings[key] = value;
    await ConfigService.saveSettings(settings);
  }
}

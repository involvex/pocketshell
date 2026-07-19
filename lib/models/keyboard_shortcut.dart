import 'package:uuid/uuid.dart';

enum ShortcutAction {
  newConnection,
  profiles,
  discovery,
  keys,
  tabChar,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  home,
  end,
  ctrlC,
  ctrlD,
  ctrlZ,
  ctrlL,
  ctrlA,
  ctrlP,
  ctrlV,
}

class KeyboardShortcut {
  final String id;
  final String label;
  final String description;
  final ShortcutAction action;
  final int? charCode;
  final int row;

  KeyboardShortcut({
    required this.label,
    required this.description,
    required this.action,
    String? id,
    this.charCode,
    this.row = 0,
  }) : id = id ?? const Uuid().v4();

  String get actionName {
    return switch (action) {
      ShortcutAction.newConnection => 'new_connection',
      ShortcutAction.profiles => 'profiles',
      ShortcutAction.discovery => 'discovery',
      ShortcutAction.keys => 'keys',
      ShortcutAction.tabChar => 'tab_char',
      ShortcutAction.arrowUp => 'arrow_up',
      ShortcutAction.arrowDown => 'arrow_down',
      ShortcutAction.arrowLeft => 'arrow_left',
      ShortcutAction.arrowRight => 'arrow_right',
      ShortcutAction.home => 'home',
      ShortcutAction.end => 'end',
      ShortcutAction.ctrlC => 'ctrl_c',
      ShortcutAction.ctrlD => 'ctrl_d',
      ShortcutAction.ctrlZ => 'ctrl_z',
      ShortcutAction.ctrlL => 'ctrl_l',
      ShortcutAction.ctrlA => 'ctrl_a',
      ShortcutAction.ctrlP => 'ctrl_p',
      ShortcutAction.ctrlV => 'ctrl_v',
    };
  }

  static String displayNameFor(ShortcutAction action) {
    return switch (action) {
      ShortcutAction.newConnection => 'New Connection',
      ShortcutAction.profiles => 'Profiles',
      ShortcutAction.discovery => 'Discovery',
      ShortcutAction.keys => 'Keys',
      ShortcutAction.tabChar => 'Tab',
      ShortcutAction.arrowUp => 'Arrow Up',
      ShortcutAction.arrowDown => 'Arrow Down',
      ShortcutAction.arrowLeft => 'Arrow Left',
      ShortcutAction.arrowRight => 'Arrow Right',
      ShortcutAction.home => 'Home',
      ShortcutAction.end => 'End',
      ShortcutAction.ctrlC => 'Ctrl+C (Interrupt)',
      ShortcutAction.ctrlD => 'Ctrl+D (EOF)',
      ShortcutAction.ctrlZ => 'Ctrl+Z (Suspend)',
      ShortcutAction.ctrlL => 'Ctrl+L (Clear)',
      ShortcutAction.ctrlA => 'Ctrl+A',
      ShortcutAction.ctrlP => 'Ctrl+P',
      ShortcutAction.ctrlV => 'Paste',
    };
  }

  static String defaultLabelFor(ShortcutAction action) {
    return switch (action) {
      ShortcutAction.newConnection => 'Ctrl+N',
      ShortcutAction.profiles => 'Ctrl+P',
      ShortcutAction.discovery => 'Ctrl+D',
      ShortcutAction.keys => 'Ctrl+K',
      ShortcutAction.tabChar => 'Tab',
      ShortcutAction.arrowUp => '↑',
      ShortcutAction.arrowDown => '↓',
      ShortcutAction.arrowLeft => '←',
      ShortcutAction.arrowRight => '→',
      ShortcutAction.home => 'Home',
      ShortcutAction.end => 'End',
      ShortcutAction.ctrlC => 'Ctrl+C',
      ShortcutAction.ctrlD => 'Ctrl+D',
      ShortcutAction.ctrlZ => 'Ctrl+Z',
      ShortcutAction.ctrlL => 'Ctrl+L',
      ShortcutAction.ctrlA => 'Ctrl+A',
      ShortcutAction.ctrlP => 'Ctrl+P',
      ShortcutAction.ctrlV => 'Ctrl+V',
    };
  }

  static String defaultDescriptionFor(ShortcutAction action) {
    return switch (action) {
      ShortcutAction.newConnection => 'New Connection',
      ShortcutAction.profiles => 'Profiles',
      ShortcutAction.discovery => 'Discovery',
      ShortcutAction.keys => 'Keys',
      ShortcutAction.tabChar => 'Tab',
      ShortcutAction.arrowUp => 'Arrow Up',
      ShortcutAction.arrowDown => 'Arrow Down',
      ShortcutAction.arrowLeft => 'Arrow Left',
      ShortcutAction.arrowRight => 'Arrow Right',
      ShortcutAction.home => 'Home',
      ShortcutAction.end => 'End',
      ShortcutAction.ctrlC => 'Interrupt',
      ShortcutAction.ctrlD => 'EOF',
      ShortcutAction.ctrlZ => 'Suspend',
      ShortcutAction.ctrlL => 'Clear',
      ShortcutAction.ctrlA => 'Select All / Line Start',
      ShortcutAction.ctrlP => 'Previous',
      ShortcutAction.ctrlV => 'Paste',
    };
  }

  static int? defaultCharCodeFor(ShortcutAction action) {
    return switch (action) {
      ShortcutAction.tabChar => 9,
      ShortcutAction.ctrlC => 3,
      ShortcutAction.ctrlD => 4,
      ShortcutAction.ctrlZ => 26,
      ShortcutAction.ctrlL => 12,
      ShortcutAction.ctrlA => 1,
      ShortcutAction.ctrlP => 16,
      _ => null,
    };
  }

  static List<ShortcutAction> actionsForRow(int row) {
    return switch (row) {
      0 => <ShortcutAction>[
          ShortcutAction.newConnection,
          ShortcutAction.profiles,
          ShortcutAction.discovery,
          ShortcutAction.keys,
        ],
      1 => <ShortcutAction>[
          ShortcutAction.tabChar,
          ShortcutAction.arrowLeft,
          ShortcutAction.arrowRight,
          ShortcutAction.arrowUp,
          ShortcutAction.arrowDown,
          ShortcutAction.home,
          ShortcutAction.end,
          ShortcutAction.ctrlV,
        ],
      _ => <ShortcutAction>[
          ShortcutAction.ctrlC,
          ShortcutAction.ctrlD,
          ShortcutAction.ctrlZ,
          ShortcutAction.ctrlL,
          ShortcutAction.ctrlA,
          ShortcutAction.ctrlP,
          ShortcutAction.ctrlV,
        ],
    };
  }

  static KeyboardShortcut createForAction(
    ShortcutAction action, {
    required int row,
    String? id,
    String? label,
    String? description,
  }) {
    return KeyboardShortcut(
      id: id,
      label: label ?? defaultLabelFor(action),
      description: description ?? defaultDescriptionFor(action),
      action: action,
      charCode: defaultCharCodeFor(action),
      row: row,
    );
  }

  KeyboardShortcut copyWith({
    String? id,
    String? label,
    String? description,
    ShortcutAction? action,
    int? charCode,
    int? row,
  }) {
    return KeyboardShortcut(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      action: action ?? this.action,
      charCode: charCode ?? this.charCode,
      row: row ?? this.row,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'description': description,
      'action': actionName,
      'charCode': charCode,
      'row': row,
    };
  }

  factory KeyboardShortcut.fromJson(Map<String, dynamic> json) {
    return KeyboardShortcut(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      action: _actionFromString(json['action'] as String),
      charCode: json['charCode'] as int?,
      row: json['row'] as int? ?? 0,
    );
  }

  static ShortcutAction _actionFromString(String action) {
    return switch (action) {
      'new_connection' => ShortcutAction.newConnection,
      'profiles' => ShortcutAction.profiles,
      'discovery' => ShortcutAction.discovery,
      'keys' => ShortcutAction.keys,
      'tab_char' => ShortcutAction.tabChar,
      'arrow_up' => ShortcutAction.arrowUp,
      'arrow_down' => ShortcutAction.arrowDown,
      'arrow_left' => ShortcutAction.arrowLeft,
      'arrow_right' => ShortcutAction.arrowRight,
      'home' => ShortcutAction.home,
      'end' => ShortcutAction.end,
      'ctrl_c' => ShortcutAction.ctrlC,
      'ctrl_d' => ShortcutAction.ctrlD,
      'ctrl_z' => ShortcutAction.ctrlZ,
      'ctrl_l' => ShortcutAction.ctrlL,
      'ctrl_a' => ShortcutAction.ctrlA,
      'ctrl_p' => ShortcutAction.ctrlP,
      'ctrl_v' => ShortcutAction.ctrlV,
      _ => ShortcutAction.newConnection,
    };
  }

  static List<KeyboardShortcut> get defaults => <KeyboardShortcut>[
        createForAction(ShortcutAction.newConnection, row: 0),
        createForAction(ShortcutAction.profiles, row: 0),
        createForAction(ShortcutAction.discovery, row: 0),
        createForAction(ShortcutAction.keys, row: 0),
        createForAction(ShortcutAction.tabChar, row: 1),
        createForAction(ShortcutAction.arrowLeft, row: 1),
        createForAction(ShortcutAction.arrowRight, row: 1),
        createForAction(ShortcutAction.arrowUp, row: 1),
        createForAction(ShortcutAction.arrowDown, row: 1),
        createForAction(ShortcutAction.home, row: 1),
        createForAction(ShortcutAction.end, row: 1),
        createForAction(ShortcutAction.ctrlC, row: 2),
        createForAction(ShortcutAction.ctrlD, row: 2),
        createForAction(ShortcutAction.ctrlZ, row: 2),
        createForAction(ShortcutAction.ctrlL, row: 2),
        createForAction(ShortcutAction.ctrlV, row: 2),
      ];
}

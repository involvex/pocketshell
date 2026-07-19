# Configure Shortcuts Edit & Reorder Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users add/edit real keyboard shortcuts (action + label + description + charCode) in Settings → Configure Shortcuts, and make drag-to-reorder work on Android.

**Architecture:** Keep `KeyboardShortcut` / `SettingsProvider.updateShortcuts` as the persistence model. Extract pure helpers for action metadata and in-row reorder so logic is unit-testable. Rework `ShortcutEditor` so it is scroll-safe inside the Settings `ListView`, wires a real drag handle, and opens an edit dialog on Add / tile tap.

**Tech Stack:** Flutter 3.47+ (`ReorderableListView.onReorderItem`), Provider, `shared_preferences` via `ConfigService`, `flutter_test`.

## Global Constraints

- Package imports must use `package:ssh_app/...` (not relative `../`).
- Prefer single quotes; `always_declare_return_types`; `prefer_const_constructors` / `prefer_final_locals`.
- Guard `BuildContext` after `await` with `if (!mounted) return`.
- Persistence only through `SettingsProvider` → `ConfigService` (never call SharedPreferences from widgets).
- Primary target is Android; drag must work with touch (immediate drag from handle, not long-press-only).
- Do not change `ShortcutAction` enum values or JSON `action` string encoding (`actionName` / `_actionFromString`).
- Display name remains PocketShell; package id stays `ssh_app`.
- Run `flutter analyze` and `flutter test` before considering the work done.

## Root Cause (investigation)

Observed in `lib/widgets/shortcut_editor.dart` + `lib/screens/settings_screen.dart`:

1. **Add creates a dead stub.** `_addShortcut()` hardcodes `label: 'New'`, `description: 'New Shortcut'`, `action: ShortcutAction.newConnection`. There is no action picker and no edit UI.
2. **Edit callback is dead code.** `_ShortcutTile` accepts `onLabelChanged` but never calls it; the tile is display-only (`Text` + delete).
3. **Reorder fights the parent scroll view.** `ShortcutEditor` embeds `ReorderableListView` inside an `ExpansionTile` that lives in Settings' outer `ListView`. Nested scrollables steal drag gestures.
4. **Drag handle is cosmetic.** Leading `Icons.drag_handle` is not wrapped in `ReorderableDragStartListener`. On Android, default reorder uses delayed long-press on the whole row, which competes with the parent `ListView` scroll — so reorder appears broken.
5. **Save pops Settings.** `_save()` calls `Navigator.pop(context)` even though the editor is embedded (not a route), so Save closes the Settings screen instead of confirming in place.
6. **Oversized nested viewport.** `height: MediaQuery.size.height * 0.75` inside the expansion tile worsens nested scrolling.

`onReorderItem` itself is valid on Flutter 3.47 (replaces obsolete `onReorder` and already adjusts `newIndex`). The callback signature is not the bug.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/models/keyboard_shortcut.dart` | Add `ShortcutActionMeta` catalog + `KeyboardShortcut.metaFor` / `fromAction` helpers |
| `lib/utils/shortcut_reorder.dart` | Pure `reorderShortcutsInRow(...)` used by editor + unit tests |
| `lib/widgets/shortcut_editor.dart` | Edit dialog, wired drag handle, scroll-safe list, save without pop |
| `lib/screens/settings_screen.dart` | Minor: drop redundant preview bar if it fights layout (optional, only if needed) |
| `test/models/keyboard_shortcut_meta_test.dart` | Action metadata / factory tests |
| `test/utils/shortcut_reorder_test.dart` | Reorder helper tests |
| `test/widgets/shortcut_editor_test.dart` | Widget tests: add→edit, reorder handle present |

---

### Task 1: Shortcut action metadata helpers

**Files:**
- Modify: `lib/models/keyboard_shortcut.dart`
- Test: `test/models/keyboard_shortcut_meta_test.dart`

**Interfaces:**
- Consumes: existing `ShortcutAction`, `KeyboardShortcut`
- Produces:
  - `class ShortcutActionMeta { final String label; final String description; final int? charCode; final int defaultRow; }`
  - `static ShortcutActionMeta metaFor(ShortcutAction action)`
  - `static KeyboardShortcut fromAction(ShortcutAction action, {required int row, String? id})`
  - `static String displayName(ShortcutAction action)` (human label for dropdown)

- [ ] **Step 1: Write the failing test**

Create `test/models/keyboard_shortcut_meta_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';

void main() {
  group('ShortcutActionMeta', () {
    test('metaFor ctrlD matches defaults', () {
      final ShortcutActionMeta meta =
          KeyboardShortcut.metaFor(ShortcutAction.ctrlD);
      expect(meta.label, 'Ctrl+D');
      expect(meta.description, 'EOF');
      expect(meta.charCode, 4);
      expect(meta.defaultRow, 2);
    });

    test('fromAction builds shortcut for selected row', () {
      final KeyboardShortcut shortcut = KeyboardShortcut.fromAction(
        ShortcutAction.ctrlC,
        row: 2,
      );
      expect(shortcut.label, 'Ctrl+C');
      expect(shortcut.description, 'Interrupt');
      expect(shortcut.action, ShortcutAction.ctrlC);
      expect(shortcut.charCode, 3);
      expect(shortcut.row, 2);
      expect(shortcut.id, isNotEmpty);
    });

    test('displayName is non-empty for every action', () {
      for (final ShortcutAction action in ShortcutAction.values) {
        expect(KeyboardShortcut.displayName(action), isNotEmpty);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/keyboard_shortcut_meta_test.dart`

Expected: FAIL — `metaFor` / `fromAction` / `displayName` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `lib/models/keyboard_shortcut.dart` (after the class fields / before or after `defaults`):

```dart
class ShortcutActionMeta {
  const ShortcutActionMeta({
    required this.label,
    required this.description,
    required this.defaultRow,
    this.charCode,
  });

  final String label;
  final String description;
  final int? charCode;
  final int defaultRow;
}

// Inside KeyboardShortcut:
static ShortcutActionMeta metaFor(ShortcutAction action) {
  return switch (action) {
    ShortcutAction.newConnection => const ShortcutActionMeta(
        label: 'Ctrl+N',
        description: 'New Connection',
        defaultRow: 0,
      ),
    ShortcutAction.profiles => const ShortcutActionMeta(
        label: 'Ctrl+P',
        description: 'Profiles',
        defaultRow: 0,
      ),
    ShortcutAction.discovery => const ShortcutActionMeta(
        label: 'Ctrl+D',
        description: 'Discovery',
        defaultRow: 0,
      ),
    ShortcutAction.keys => const ShortcutActionMeta(
        label: 'Ctrl+K',
        description: 'Keys',
        defaultRow: 0,
      ),
    ShortcutAction.tabChar => const ShortcutActionMeta(
        label: 'Tab',
        description: 'Tab',
        charCode: 9,
        defaultRow: 1,
      ),
    ShortcutAction.arrowLeft => const ShortcutActionMeta(
        label: '←',
        description: 'Arrow Left',
        defaultRow: 1,
      ),
    ShortcutAction.arrowRight => const ShortcutActionMeta(
        label: '→',
        description: 'Arrow Right',
        defaultRow: 1,
      ),
    ShortcutAction.arrowUp => const ShortcutActionMeta(
        label: '↑',
        description: 'Arrow Up',
        defaultRow: 1,
      ),
    ShortcutAction.arrowDown => const ShortcutActionMeta(
        label: '↓',
        description: 'Arrow Down',
        defaultRow: 1,
      ),
    ShortcutAction.home => const ShortcutActionMeta(
        label: 'Home',
        description: 'Home',
        defaultRow: 1,
      ),
    ShortcutAction.end => const ShortcutActionMeta(
        label: 'End',
        description: 'End',
        defaultRow: 1,
      ),
    ShortcutAction.ctrlC => const ShortcutActionMeta(
        label: 'Ctrl+C',
        description: 'Interrupt',
        charCode: 3,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlD => const ShortcutActionMeta(
        label: 'Ctrl+D',
        description: 'EOF',
        charCode: 4,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlZ => const ShortcutActionMeta(
        label: 'Ctrl+Z',
        description: 'Suspend',
        charCode: 26,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlL => const ShortcutActionMeta(
        label: 'Ctrl+L',
        description: 'Clear',
        charCode: 12,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlA => const ShortcutActionMeta(
        label: 'Ctrl+A',
        description: 'Start of line',
        charCode: 1,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlP => const ShortcutActionMeta(
        label: 'Ctrl+P',
        description: 'Previous',
        charCode: 16,
        defaultRow: 2,
      ),
    ShortcutAction.ctrlV => const ShortcutActionMeta(
        label: 'Ctrl+V',
        description: 'Paste',
        defaultRow: 2,
      ),
  };
}

static String displayName(ShortcutAction action) {
  final ShortcutActionMeta meta = metaFor(action);
  return '${meta.label} — ${meta.description}';
}

static KeyboardShortcut fromAction(
  ShortcutAction action, {
  required int row,
  String? id,
}) {
  final ShortcutActionMeta meta = metaFor(action);
  return KeyboardShortcut(
    id: id,
    label: meta.label,
    description: meta.description,
    action: action,
    charCode: meta.charCode,
    row: row,
  );
}
```

Optionally refactor `defaults` to call `fromAction` so labels stay single-sourced — only if it stays a small diff.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/keyboard_shortcut_meta_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/keyboard_shortcut.dart test/models/keyboard_shortcut_meta_test.dart
git commit -m "feat(shortcuts): add action metadata helpers for editor"
```

---

### Task 2: Pure in-row reorder helper

**Files:**
- Create: `lib/utils/shortcut_reorder.dart`
- Test: `test/utils/shortcut_reorder_test.dart`

**Interfaces:**
- Consumes: `List<KeyboardShortcut>`, row index, old/new indices from `onReorderItem`
- Produces:
  - `List<KeyboardShortcut> reorderShortcutsInRow({required List<KeyboardShortcut> shortcuts, required int row, required int oldIndex, required int newIndex})`
  - Preserves relative order of other rows; reorders only the selected row; returns a new list

- [ ] **Step 1: Write the failing test**

Create `test/utils/shortcut_reorder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/utils/shortcut_reorder.dart';

void main() {
  group('reorderShortcutsInRow', () {
    test('moves item within the selected row only', () {
      final List<KeyboardShortcut> input = <KeyboardShortcut>[
        KeyboardShortcut.fromAction(ShortcutAction.newConnection, row: 0),
        KeyboardShortcut.fromAction(ShortcutAction.ctrlC, row: 2),
        KeyboardShortcut.fromAction(ShortcutAction.ctrlD, row: 2),
        KeyboardShortcut.fromAction(ShortcutAction.ctrlZ, row: 2),
      ];

      final List<KeyboardShortcut> result = reorderShortcutsInRow(
        shortcuts: input,
        row: 2,
        oldIndex: 0,
        newIndex: 2,
      );

      final List<String> row2Labels = result
          .where((KeyboardShortcut s) => s.row == 2)
          .map((KeyboardShortcut s) => s.label)
          .toList();
      expect(row2Labels, <String>['Ctrl+D', 'Ctrl+Z', 'Ctrl+C']);
      expect(result.first.action, ShortcutAction.newConnection);
    });

    test('no-op when indices are equal', () {
      final List<KeyboardShortcut> input = <KeyboardShortcut>[
        KeyboardShortcut.fromAction(ShortcutAction.ctrlC, row: 2),
        KeyboardShortcut.fromAction(ShortcutAction.ctrlD, row: 2),
      ];
      final List<KeyboardShortcut> result = reorderShortcutsInRow(
        shortcuts: input,
        row: 2,
        oldIndex: 1,
        newIndex: 1,
      );
      expect(
        result.map((KeyboardShortcut s) => s.label).toList(),
        input.map((KeyboardShortcut s) => s.label).toList(),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/shortcut_reorder_test.dart`

Expected: FAIL — library/function missing.

- [ ] **Step 3: Write minimal implementation**

Create `lib/utils/shortcut_reorder.dart`:

```dart
import 'package:ssh_app/models/keyboard_shortcut.dart';

/// Reorders shortcuts that share [row], leaving other rows' relative order
/// unchanged. [oldIndex]/[newIndex] are indices within that row only, as
/// delivered by [ReorderableListView.onReorderItem] (already adjusted).
List<KeyboardShortcut> reorderShortcutsInRow({
  required List<KeyboardShortcut> shortcuts,
  required int row,
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex == newIndex) {
    return List<KeyboardShortcut>.from(shortcuts);
  }

  final List<KeyboardShortcut> rowItems = shortcuts
      .where((KeyboardShortcut s) => s.row == row)
      .toList();
  final List<KeyboardShortcut> otherItems = shortcuts
      .where((KeyboardShortcut s) => s.row != row)
      .toList();

  if (oldIndex < 0 ||
      oldIndex >= rowItems.length ||
      newIndex < 0 ||
      newIndex >= rowItems.length) {
    return List<KeyboardShortcut>.from(shortcuts);
  }

  final KeyboardShortcut item = rowItems.removeAt(oldIndex);
  rowItems.insert(newIndex, item);

  // Rebuild in original row-block order: walk original list, emit other
  // rows in place, and splice the reordered row block at the first
  // occurrence of that row (or append if the row was empty before).
  final List<KeyboardShortcut> result = <KeyboardShortcut>[];
  var rowInserted = false;
  for (final KeyboardShortcut s in shortcuts) {
    if (s.row == row) {
      if (!rowInserted) {
        result.addAll(rowItems);
        rowInserted = true;
      }
    } else {
      result.add(s);
    }
  }
  if (!rowInserted) {
    result.addAll(rowItems);
  }

  // Silence unused if analyzer complains when otherItems unused — prefer
  // the walk above; delete otherItems if unused.
  assert(otherItems.length + rowItems.length == shortcuts.length);
  return result;
}
```

Prefer the walk-based rebuild (keeps other rows in their prior positions). Drop the unused `otherItems` list if the analyzer flags it — keep only the walk.

Cleaner final version without unused locals:

```dart
import 'package:ssh_app/models/keyboard_shortcut.dart';

List<KeyboardShortcut> reorderShortcutsInRow({
  required List<KeyboardShortcut> shortcuts,
  required int row,
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex == newIndex) {
    return List<KeyboardShortcut>.from(shortcuts);
  }

  final List<KeyboardShortcut> rowItems = shortcuts
      .where((KeyboardShortcut s) => s.row == row)
      .toList();

  if (oldIndex < 0 ||
      oldIndex >= rowItems.length ||
      newIndex < 0 ||
      newIndex >= rowItems.length) {
    return List<KeyboardShortcut>.from(shortcuts);
  }

  final KeyboardShortcut moved = rowItems.removeAt(oldIndex);
  rowItems.insert(newIndex, moved);

  final List<KeyboardShortcut> result = <KeyboardShortcut>[];
  var rowInserted = false;
  for (final KeyboardShortcut s in shortcuts) {
    if (s.row != row) {
      result.add(s);
      continue;
    }
    if (!rowInserted) {
      result.addAll(rowItems);
      rowInserted = true;
    }
  }
  if (!rowInserted) {
    result.addAll(rowItems);
  }
  return result;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/shortcut_reorder_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/utils/shortcut_reorder.dart test/utils/shortcut_reorder_test.dart
git commit -m "feat(shortcuts): add pure in-row reorder helper"
```

---

### Task 3: Edit dialog + Add creates a real shortcut

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Test: `test/widgets/shortcut_editor_test.dart`

**Interfaces:**
- Consumes: `KeyboardShortcut.fromAction`, `KeyboardShortcut.metaFor`, `KeyboardShortcut.displayName`, `SettingsProvider.updateShortcuts`
- Produces:
  - `_addShortcut()` opens dialog; on confirm appends fully configured shortcut
  - Tap on tile opens same dialog for edit (updates label/description/action/charCode)
  - Delete unchanged

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/shortcut_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/widgets/shortcut_editor.dart';

Future<void> _pumpEditor(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await ConfigService.init();
  final SettingsProvider settings = SettingsProvider();
  await settings.loadSettings();

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShortcutEditor(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add opens editor and applies chosen action',
      (WidgetTester tester) async {
    await _pumpEditor(tester);

    // Switch to Ctrl row (value 2)
    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Shortcut'), findsOneWidget);

    // Pick Ctrl+A from the dropdown (displayName contains Ctrl+A)
    await tester.tap(find.byType(DropdownButtonFormField<ShortcutAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(KeyboardShortcut.displayName(ShortcutAction.ctrlA)).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+A'), findsWidgets);
    expect(find.text('Start of line'), findsWidgets);
    expect(find.text('New'), findsNothing);
  });
}
```

If `ConfigService.init` / `SettingsProvider` setup differs, mirror the pattern used in existing provider tests. Adjust finder strings to match the dialog copy defined in Step 3 (`Edit Shortcut`, `Apply`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL — Add does not show dialog / still inserts `New`.

- [ ] **Step 3: Implement dialog + wire Add/edit**

In `lib/widgets/shortcut_editor.dart`:

1. Switch imports to `package:ssh_app/...`.
2. Replace `_addShortcut` with async dialog flow.
3. Add `_editShortcut(KeyboardShortcut? existing)` that shows `AlertDialog` with:
   - `DropdownButtonFormField<ShortcutAction>` of `ShortcutAction.values`
   - `TextFormField` for label
   - `TextFormField` for description
   - On action change: refill label/description from `KeyboardShortcut.metaFor`
   - Actions: Cancel / Apply
4. On Apply for new: `KeyboardShortcut.fromAction(action, row: _selectedRow)` then override label/description if user edited them (keep `charCode` from meta).
5. On Apply for existing: `copyWith(action:, label:, description:, charCode: meta.charCode)`.
6. Make `_ShortcutTile` tappable (`onTap: onEdit`) and remove unused `onLabelChanged`.

Dialog sketch:

```dart
Future<KeyboardShortcut?> _showShortcutDialog({
  KeyboardShortcut? existing,
}) async {
  ShortcutAction action =
      existing?.action ?? ShortcutAction.ctrlC;
  final TextEditingController labelController = TextEditingController(
    text: existing?.label ?? KeyboardShortcut.metaFor(action).label,
  );
  final TextEditingController descriptionController =
      TextEditingController(
    text: existing?.description ??
        KeyboardShortcut.metaFor(action).description,
  );

  final KeyboardShortcut? result = await showDialog<KeyboardShortcut>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Shortcut' : 'Edit Shortcut'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<ShortcutAction>(
                    // ignore: deprecated_member_use if value→initialValue migration required
                    value: action,
                    items: ShortcutAction.values
                        .map(
                          (ShortcutAction a) => DropdownMenuItem<ShortcutAction>(
                            value: a,
                            child: Text(KeyboardShortcut.displayName(a)),
                          ),
                        )
                        .toList(),
                    onChanged: (ShortcutAction? next) {
                      if (next == null) return;
                      setDialogState(() {
                        action = next;
                        final ShortcutActionMeta meta =
                            KeyboardShortcut.metaFor(next);
                        labelController.text = meta.label;
                        descriptionController.text = meta.description;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Action'),
                  ),
                  TextFormField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final ShortcutActionMeta meta =
                      KeyboardShortcut.metaFor(action);
                  final KeyboardShortcut shortcut = existing == null
                      ? KeyboardShortcut(
                          label: labelController.text.trim().isEmpty
                              ? meta.label
                              : labelController.text.trim(),
                          description:
                              descriptionController.text.trim().isEmpty
                                  ? meta.description
                                  : descriptionController.text.trim(),
                          action: action,
                          charCode: meta.charCode,
                          row: _selectedRow,
                        )
                      : existing.copyWith(
                          label: labelController.text.trim().isEmpty
                              ? meta.label
                              : labelController.text.trim(),
                          description:
                              descriptionController.text.trim().isEmpty
                                  ? meta.description
                                  : descriptionController.text.trim(),
                          action: action,
                          charCode: meta.charCode,
                        );
                  Navigator.pop(dialogContext, shortcut);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );

  labelController.dispose();
  descriptionController.dispose();
  return result;
}

Future<void> _addShortcut() async {
  final KeyboardShortcut? created = await _showShortcutDialog();
  if (created == null || !mounted) return;
  setState(() => _shortcuts.add(created));
}

Future<void> _editShortcut(KeyboardShortcut shortcut) async {
  final KeyboardShortcut? updated =
      await _showShortcutDialog(existing: shortcut);
  if (updated == null || !mounted) return;
  setState(() {
    final int idx =
        _shortcuts.indexWhere((KeyboardShortcut s) => s.id == shortcut.id);
    if (idx >= 0) {
      _shortcuts[idx] = updated;
    }
  });
}
```

Wire tile:

```dart
return _ShortcutTile(
  key: ValueKey<String>(shortcut.id),
  shortcut: shortcut,
  index: index,
  onDelete: () => _removeShortcut(shortcut),
  onEdit: () => _editShortcut(shortcut),
);
```

Update test title finder to `'Add Shortcut'` for the add path (use that string in the test from Step 1 if you prefer consistency — keep dialog title `Add Shortcut` / `Edit Shortcut`, and assert `find.text('Add Shortcut')` in the Add test).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_editor_test.dart
git commit -m "feat(shortcuts): add/edit dialog for real shortcut actions"
```

---

### Task 4: Fix drag reorder + save behavior

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Modify: `test/widgets/shortcut_editor_test.dart` (add reorder/save assertions)

**Interfaces:**
- Consumes: `reorderShortcutsInRow`, `ReorderableDragStartListener`
- Produces: working handle-drag reorder; Save persists and shows SnackBar (no `Navigator.pop`)

- [ ] **Step 1: Write/extend failing test**

Add to `test/widgets/shortcut_editor_test.dart`:

```dart
testWidgets('list uses drag start listener and save does not pop route',
    (WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await ConfigService.init();
  final SettingsProvider settings = SettingsProvider();
  await settings.loadSettings();

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ListView(
                children: const <Widget>[
                  ShortcutEditor(),
                  Text('AfterEditor'),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Text('OtherRoute'),
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.navigation),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(ReorderableDragStartListener), findsWidgets);

  await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
  await tester.pumpAndSettle();

  // Still on the settings-like page; Save must not pop the route.
  expect(find.text('AfterEditor'), findsOneWidget);
  expect(find.text('OtherRoute'), findsNothing);
  expect(find.text('Shortcuts saved'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL — no `ReorderableDragStartListener` / Save pops or no SnackBar.

- [ ] **Step 3: Fix editor layout, drag handle, reorder, save**

Rewrite the list section of `ShortcutEditor.build` as follows:

1. Remove outer `Material` + fixed `height: MediaQuery... * 0.75` + `Expanded` around the list.
2. Use a `Column` with `mainAxisSize: MainAxisSize.min`.
3. Configure reorderable list for nesting inside Settings `ListView`:

```dart
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  buildDefaultDragHandles: false,
  itemCount: _currentRowShortcuts.length,
  onReorderItem: (int oldIndex, int newIndex) {
    setState(() {
      _shortcuts = reorderShortcutsInRow(
        shortcuts: _shortcuts,
        row: _selectedRow,
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
    });
  },
  itemBuilder: (BuildContext context, int index) {
    final KeyboardShortcut shortcut = _currentRowShortcuts[index];
    return _ShortcutTile(
      key: ValueKey<String>(shortcut.id),
      shortcut: shortcut,
      index: index,
      onDelete: () => _removeShortcut(shortcut),
      onEdit: () => _editShortcut(shortcut),
    );
  },
)
```

4. Wire the visible handle:

```dart
class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.shortcut,
    required this.index,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });

  final KeyboardShortcut shortcut;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onEdit,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(shortcut.label),
        subtitle: Text(shortcut.description),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
```

Do **not** put a second `Key` on the inner `Card` (key belongs on the widget returned by `itemBuilder` only).

5. Fix save:

```dart
Future<void> _save() async {
  final SettingsProvider settings = context.read<SettingsProvider>();
  await settings.updateShortcuts(_shortcuts);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Shortcuts saved')),
  );
}
```

6. Delete the old `_onReorderItem` body that rebuilt with `[...other, ...row]` at the end (replaced by `reorderShortcutsInRow`).

- [ ] **Step 4: Run tests + analyze**

Run:

```bash
flutter test test/models/keyboard_shortcut_meta_test.dart test/utils/shortcut_reorder_test.dart test/widgets/shortcut_editor_test.dart
flutter analyze lib/models/keyboard_shortcut.dart lib/utils/shortcut_reorder.dart lib/widgets/shortcut_editor.dart
```

Expected: all PASS / No issues found.

- [ ] **Step 5: Manual Android check**

On device/emulator:

1. Settings → Configure Shortcuts → expand.
2. Ctrl row → Add → pick Ctrl+A → Apply → see Ctrl+A / Start of line.
3. Drag via the handle to reorder; order sticks after Save.
4. Save stays on Settings and shows "Shortcuts saved".
5. Return to Client terminal shortcut bar and confirm order/actions match.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_editor_test.dart
git commit -m "fix(shortcuts): wire drag handle and nested-scroll reorder; save in place"
```

---

### Task 5: Full verification

**Files:**
- None (verification only)

- [ ] **Step 1: Format**

Run: `dart format lib/models/keyboard_shortcut.dart lib/utils/shortcut_reorder.dart lib/widgets/shortcut_editor.dart test/models/keyboard_shortcut_meta_test.dart test/utils/shortcut_reorder_test.dart test/widgets/shortcut_editor_test.dart`

- [ ] **Step 2: Analyze + test suite**

Run:

```bash
flutter analyze
flutter test
```

Expected: no analyzer errors; all tests pass. (`assets/` missing directory warning is pre-existing and OK.)

- [ ] **Step 3: Commit any format-only diffs**

```bash
git add -A
git commit -m "chore(shortcuts): format edit/reorder fix"
```

(Only if format changed files.)

---

## Self-Review

1. **Spec coverage:** Add editable shortcut ✓, apply real action/charCode ✓, drag reorder ✓, save without leaving Settings ✓, nested scroll fix ✓, tests ✓.
2. **Placeholder scan:** No TBD/TODO steps; code blocks are complete.
3. **Type consistency:** `ShortcutActionMeta`, `metaFor`, `fromAction`, `displayName`, `reorderShortcutsInRow` names match across tasks.

## Out of scope (YAGNI)

- Custom arbitrary key capture / recording chords outside `ShortcutAction`.
- Per-profile shortcut sets.
- Changing how `KeyboardShortcutBar` executes actions.
- Redesigning Settings navigation.

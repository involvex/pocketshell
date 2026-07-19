# Configure Shortcuts Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Configure Shortcuts able to add/edit real shortcut actions and reorder them via drag handles.

**Architecture:** Add a small `ShortcutAction` metadata catalog on the model (default label, description, charCode). Open `ShortcutEditor` as a modal bottom sheet (not nested inside Settings’ `ListView`) so reorder gestures work. Wire Add/tile tap to an edit dialog that picks a `ShortcutAction` and fills label/description/charCode. Use explicit `ReorderableDragStartListener` on the leading handle.

**Tech Stack:** Flutter 3.47+, Dart 3.13+, Provider, `shared_preferences` via `ConfigService`, `flutter_test`

## Global Constraints

- Persistence must go through `SettingsProvider.updateShortcuts` / `ConfigService` — never call SharedPreferences from widgets.
- Keep `strict-casts` / `strict-raw-types` / `prefer_single_quotes` / `always_declare_return_types` satisfied (`flutter analyze` clean).
- Guard `BuildContext` after `await` with `if (!mounted) return`.
- Android is the primary product target; drag must work with finger (handle drag + long-press).
- Do not rename package/id (`ssh_app`); display name stays PocketShell.
- YAGNI: no custom key-chord recorder, no new action types beyond existing `ShortcutAction` enum.
- Imports: Dart SDK → packages → `package:ssh_app/...`, alphabetical within groups.

## Root Cause Summary (investigation)

Two independent bugs in `lib/widgets/shortcut_editor.dart`:

1. **Add stuck on "New"** — `_addShortcut()` hardcodes `label: 'New'`, `description: 'New Shortcut'`, `action: ShortcutAction.newConnection`. `_ShortcutTile` accepts `onLabelChanged` but never uses it (no tap, no TextField, no action picker). Users cannot choose a real action.

2. **Drag reorder fails** — `ShortcutEditor` is embedded inside Settings’ outer `ListView` (`lib/screens/settings_screen.dart` ExpansionTile). Nested scrollables steal vertical drag. The left `Icons.drag_handle` is decorative only; on desktop Flutter’s default handle is on the **right**, so the visible left handle does nothing. `_save()` also calls `Navigator.pop`, which is wrong while the editor is not a route (pops Settings).

`onReorderItem` itself is the correct Flutter 3.47 API (replaces deprecated `onReorder`).

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/models/keyboard_shortcut.dart` | Add `ShortcutActionMeta` / helpers: default label, description, charCode per action |
| `lib/widgets/shortcut_editor.dart` | Modal-ready editor: edit dialog, wired drag handles, fix save/reorder |
| `lib/screens/settings_screen.dart` | Replace embedded editor with a tile that opens the modal sheet |
| `test/models/keyboard_shortcut_meta_test.dart` | Unit tests for action metadata |
| `test/widgets/shortcut_editor_test.dart` | Widget tests: add→edit action, reorder callback updates order |

---

### Task 1: ShortcutAction metadata helpers

**Files:**
- Modify: `lib/models/keyboard_shortcut.dart`
- Test: `test/models/keyboard_shortcut_meta_test.dart`

**Interfaces:**
- Consumes: existing `ShortcutAction` enum and `KeyboardShortcut` fields
- Produces:
  - `class ShortcutActionMeta { final String label; final String description; final int? charCode; const ShortcutActionMeta(...); }`
  - `ShortcutActionMeta shortcutActionMeta(ShortcutAction action)`
  - `KeyboardShortcut KeyboardShortcut.fromAction(ShortcutAction action, {required int row, String? id})`

- [ ] **Step 1: Write the failing test**

Create `test/models/keyboard_shortcut_meta_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';

void main() {
  group('shortcutActionMeta', () {
    test('maps ctrlD to EOF with charCode 4', () {
      final ShortcutActionMeta meta = shortcutActionMeta(ShortcutAction.ctrlD);
      expect(meta.label, 'Ctrl+D');
      expect(meta.description, 'EOF');
      expect(meta.charCode, 4);
    });

    test('maps tabChar to Tab with charCode 9', () {
      final ShortcutActionMeta meta = shortcutActionMeta(ShortcutAction.tabChar);
      expect(meta.label, 'Tab');
      expect(meta.description, 'Tab');
      expect(meta.charCode, 9);
    });

    test('maps ctrlV paste with null charCode', () {
      final ShortcutActionMeta meta = shortcutActionMeta(ShortcutAction.ctrlV);
      expect(meta.label, 'Ctrl+V');
      expect(meta.description, 'Paste');
      expect(meta.charCode, isNull);
    });
  });

  group('KeyboardShortcut.fromAction', () {
    test('builds shortcut for selected row using meta defaults', () {
      final KeyboardShortcut shortcut = KeyboardShortcut.fromAction(
        ShortcutAction.ctrlC,
        row: 2,
      );
      expect(shortcut.row, 2);
      expect(shortcut.label, 'Ctrl+C');
      expect(shortcut.description, 'Interrupt');
      expect(shortcut.charCode, 3);
      expect(shortcut.action, ShortcutAction.ctrlC);
      expect(shortcut.id, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/keyboard_shortcut_meta_test.dart`

Expected: FAIL — `shortcutActionMeta` / `ShortcutActionMeta` / `fromAction` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `lib/models/keyboard_shortcut.dart` (after the enum, before or after the class — keep `ShortcutActionMeta` as a top-level class in the same file):

```dart
class ShortcutActionMeta {
  final String label;
  final String description;
  final int? charCode;

  const ShortcutActionMeta({
    required this.label,
    required this.description,
    this.charCode,
  });
}

ShortcutActionMeta shortcutActionMeta(ShortcutAction action) {
  return switch (action) {
    ShortcutAction.newConnection => const ShortcutActionMeta(
        label: 'Ctrl+N',
        description: 'New Connection',
      ),
    ShortcutAction.profiles => const ShortcutActionMeta(
        label: 'Ctrl+P',
        description: 'Profiles',
      ),
    ShortcutAction.discovery => const ShortcutActionMeta(
        label: 'Ctrl+D',
        description: 'Discovery',
      ),
    ShortcutAction.keys => const ShortcutActionMeta(
        label: 'Ctrl+K',
        description: 'Keys',
      ),
    ShortcutAction.tabChar => const ShortcutActionMeta(
        label: 'Tab',
        description: 'Tab',
        charCode: 9,
      ),
    ShortcutAction.arrowUp => const ShortcutActionMeta(
        label: '↑',
        description: 'Arrow Up',
      ),
    ShortcutAction.arrowDown => const ShortcutActionMeta(
        label: '↓',
        description: 'Arrow Down',
      ),
    ShortcutAction.arrowLeft => const ShortcutActionMeta(
        label: '←',
        description: 'Arrow Left',
      ),
    ShortcutAction.arrowRight => const ShortcutActionMeta(
        label: '→',
        description: 'Arrow Right',
      ),
    ShortcutAction.home => const ShortcutActionMeta(
        label: 'Home',
        description: 'Home',
      ),
    ShortcutAction.end => const ShortcutActionMeta(
        label: 'End',
        description: 'End',
      ),
    ShortcutAction.ctrlC => const ShortcutActionMeta(
        label: 'Ctrl+C',
        description: 'Interrupt',
        charCode: 3,
      ),
    ShortcutAction.ctrlD => const ShortcutActionMeta(
        label: 'Ctrl+D',
        description: 'EOF',
        charCode: 4,
      ),
    ShortcutAction.ctrlZ => const ShortcutActionMeta(
        label: 'Ctrl+Z',
        description: 'Suspend',
        charCode: 26,
      ),
    ShortcutAction.ctrlL => const ShortcutActionMeta(
        label: 'Ctrl+L',
        description: 'Clear',
        charCode: 12,
      ),
    ShortcutAction.ctrlA => const ShortcutActionMeta(
        label: 'Ctrl+A',
        description: 'Start of line',
        charCode: 1,
      ),
    ShortcutAction.ctrlP => const ShortcutActionMeta(
        label: 'Ctrl+P',
        description: 'Previous',
        charCode: 16,
      ),
    ShortcutAction.ctrlV => const ShortcutActionMeta(
        label: 'Ctrl+V',
        description: 'Paste',
      ),
  };
}
```

Add factory on `KeyboardShortcut`:

```dart
factory KeyboardShortcut.fromAction(
  ShortcutAction action, {
  required int row,
  String? id,
}) {
  final ShortcutActionMeta meta = shortcutActionMeta(action);
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

Optionally refactor `defaults` to use `fromAction` for DRY (recommended, keep same labels/descriptions/charCodes/rows as today).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/keyboard_shortcut_meta_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/keyboard_shortcut.dart test/models/keyboard_shortcut_meta_test.dart
git commit -m "feat(shortcuts): add ShortcutAction metadata helpers"
```

---

### Task 2: Open ShortcutEditor as a modal (fix nesting + Save pop)

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Modify: `lib/screens/settings_screen.dart` (ExpansionTile children)
- Test: `test/widgets/shortcut_editor_test.dart` (scaffold for later tasks)

**Interfaces:**
- Consumes: `SettingsProvider.shortcuts`, `updateShortcuts`, `resetShortcuts`
- Produces:
  - `Future<void> showShortcutEditor(BuildContext context)` top-level function in `shortcut_editor.dart`
  - Settings ExpansionTile no longer embeds `ShortcutEditor` inline

- [ ] **Step 1: Write the failing test**

Create `test/widgets/shortcut_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssh_app/providers/settings_provider.dart';
import 'package:ssh_app/widgets/shortcut_editor.dart';

void main() {
  testWidgets('showShortcutEditor presents Configure Shortcuts sheet',
      (WidgetTester tester) async {
    final SettingsProvider settings = SettingsProvider();
    // Pretend loaded with defaults for UI
    settings.debugSetShortcutsForTest(KeyboardShortcut.defaults);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showShortcutEditor(context),
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Configure Shortcuts'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
```

If `debugSetShortcutsForTest` does not exist, add a narrow test-only seam on `SettingsProvider` in this task:

```dart
@visibleForTesting
void debugSetShortcutsForTest(List<KeyboardShortcut> shortcuts) {
  _shortcuts = List<KeyboardShortcut>.from(shortcuts);
  _isLoaded = true;
  notifyListeners();
}
```

Import `package:flutter/foundation.dart` for `@visibleForTesting` and `KeyboardShortcut` in the test.

Alternatively (YAGNI-friendly): construct the widget tree with a fake that only needs `isLoaded`/`shortcuts` if extracting an interface is too large — prefer the `@visibleForTesting` setter to avoid architecture churn.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL — `showShortcutEditor` not defined (and/or test helper missing).

- [ ] **Step 3: Add `showShortcutEditor` and stop embedding the editor**

In `lib/widgets/shortcut_editor.dart`, add:

```dart
Future<void> showShortcutEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => const ShortcutEditor(),
  );
}
```

In `lib/screens/settings_screen.dart`, replace the ExpansionTile children that currently include `ShortcutEditor()` with a single action tile (keep the preview bar optional):

```dart
children: [
  const KeyboardShortcutBar(showRow: 1, forceShowOnMobile: true),
  const SizedBox(height: 8),
  ListTile(
    leading: const Icon(Icons.edit),
    title: const Text('Edit shortcuts'),
    subtitle: const Text('Add, reorder, and change actions'),
    onTap: () => showShortcutEditor(context),
  ),
],
```

Ensure `showShortcutEditor` is imported from `shortcut_editor.dart`. Keep `_save()`’s `Navigator.pop` — it is now correct because the editor is a modal route.

Also change initial row selection in `_syncFromSettings` to keep the user’s last selection or default to `0` instead of forcing Ctrl (`maxRow >= 2 ? 2 : maxRow`) — prefer:

```dart
void _syncFromSettings(SettingsProvider settings) {
  _shortcuts = List<KeyboardShortcut>.from(settings.shortcuts);
}
```

and initialize `int _selectedRow = 0;` only once (do not overwrite on every sync unless resetting).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: PASS for the open-sheet test.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart lib/screens/settings_screen.dart lib/providers/settings_provider.dart test/widgets/shortcut_editor_test.dart
git commit -m "fix(shortcuts): open shortcut editor as modal bottom sheet"
```

---

### Task 3: Add/edit dialog so new shortcuts get real actions

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Test: `test/widgets/shortcut_editor_test.dart`

**Interfaces:**
- Consumes: `KeyboardShortcut.fromAction`, `shortcutActionMeta`, `ShortcutAction.values`
- Produces:
  - `_addShortcut()` opens edit dialog instead of inserting a dead "New" row
  - Tile `onTap` opens the same dialog for edits
  - Dialog returns updated `KeyboardShortcut` (label, description, action, charCode, same id/row)

- [ ] **Step 1: Write the failing test**

Append to `test/widgets/shortcut_editor_test.dart`:

```dart
testWidgets('Add opens dialog and applying Ctrl+L creates real shortcut',
    (WidgetTester tester) async {
  final SettingsProvider settings = SettingsProvider();
  settings.debugSetShortcutsForTest(<KeyboardShortcut>[]);

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MaterialApp(home: Scaffold(body: ShortcutEditor())),
    ),
  );
  await tester.pumpAndSettle();

  // Select Ctrl row
  await tester.tap(find.text('Ctrl'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();

  expect(find.text('Add Shortcut'), findsOneWidget);

  // Open action dropdown and pick Ctrl+L / Clear
  await tester.tap(find.byType(DropdownButtonFormField<ShortcutAction>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ctrl+L — Clear').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();

  expect(find.text('Ctrl+L'), findsWidgets);
  expect(find.text('Clear'), findsWidgets);
  expect(find.text('New'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL — dialog / Apply not found; "New" still inserted.

- [ ] **Step 3: Implement edit dialog and wire Add + tile tap**

Replace `_addShortcut` and extend `_ShortcutTile`:

```dart
Future<void> _addShortcut() async {
  final KeyboardShortcut? created = await _showShortcutEditDialog(
    context: context,
    row: _selectedRow,
  );
  if (!mounted || created == null) return;
  setState(() => _shortcuts.add(created));
}

Future<void> _editShortcut(KeyboardShortcut shortcut) async {
  final KeyboardShortcut? updated = await _showShortcutEditDialog(
    context: context,
    row: shortcut.row,
    existing: shortcut,
  );
  if (!mounted || updated == null) return;
  setState(() {
    final int idx = _shortcuts.indexWhere((s) => s.id == shortcut.id);
    if (idx >= 0) {
      _shortcuts[idx] = updated;
    }
  });
}

Future<KeyboardShortcut?> _showShortcutEditDialog({
  required BuildContext context,
  required int row,
  KeyboardShortcut? existing,
}) {
  ShortcutAction selected =
      existing?.action ?? ShortcutAction.ctrlC;
  final TextEditingController labelController = TextEditingController(
    text: existing?.label ?? shortcutActionMeta(selected).label,
  );
  final TextEditingController descriptionController = TextEditingController(
    text: existing?.description ?? shortcutActionMeta(selected).description,
  );

  return showDialog<KeyboardShortcut>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Shortcut' : 'Edit Shortcut'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<ShortcutAction>(
                    // ignore: deprecated_member_use
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Action'),
                    items: ShortcutAction.values
                        .map(
                          (ShortcutAction action) {
                            final ShortcutActionMeta meta =
                                shortcutActionMeta(action);
                            return DropdownMenuItem<ShortcutAction>(
                              value: action,
                              child: Text('${meta.label} — ${meta.description}'),
                            );
                          },
                        )
                        .toList(),
                    onChanged: (ShortcutAction? action) {
                      if (action == null) return;
                      final ShortcutActionMeta meta =
                          shortcutActionMeta(action);
                      setLocal(() {
                        selected = action;
                        labelController.text = meta.label;
                        descriptionController.text = meta.description;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
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
              ElevatedButton(
                onPressed: () {
                  final ShortcutActionMeta meta =
                      shortcutActionMeta(selected);
                  Navigator.pop(
                    dialogContext,
                    KeyboardShortcut(
                      id: existing?.id,
                      label: labelController.text.trim().isEmpty
                          ? meta.label
                          : labelController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? meta.description
                          : descriptionController.text.trim(),
                      action: selected,
                      charCode: meta.charCode,
                      row: row,
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );
}
```

Update list item builder:

```dart
return _ShortcutTile(
  key: ValueKey(shortcut.id),
  shortcut: shortcut,
  index: index,
  onDelete: () => _removeShortcut(shortcut),
  onEdit: () => _editShortcut(shortcut),
);
```

Rewrite `_ShortcutTile` to drop unused `onLabelChanged`, accept `onEdit` + `index`, and make the tile tappable:

```dart
class _ShortcutTile extends StatelessWidget {
  final KeyboardShortcut shortcut;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ShortcutTile({
    required this.shortcut,
    required this.index,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });

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

On the `ReorderableListView.builder`, set:

```dart
buildDefaultDragHandles: false,
```

so only the leading handle starts a drag (works on Android and desktop without long-press-only / right-side default handle confusion).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_editor_test.dart
git commit -m "feat(shortcuts): add edit dialog for real shortcut actions"
```

---

### Task 4: Make reorder persist correctly within a row

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart` (`_onReorderItem`)
- Test: `test/widgets/shortcut_editor_test.dart` (or unit-test the reorder helper)

**Interfaces:**
- Consumes: `_shortcuts`, `_selectedRow`, `onReorderItem(oldIndex, newIndex)` (already adjusted by Flutter)
- Produces: `_shortcuts` where relative order of the selected row matches the drag result; other rows’ relative order unchanged

- [ ] **Step 1: Write the failing test**

Prefer extracting a pure helper so the test does not fight gesture flakiness:

In `lib/widgets/shortcut_editor.dart` (top-level or library-private):

```dart
List<KeyboardShortcut> reorderShortcutsInRow({
  required List<KeyboardShortcut> shortcuts,
  required int row,
  required int oldIndex,
  required int newIndex,
}) {
  final List<KeyboardShortcut> rowItems =
      shortcuts.where((s) => s.row == row).toList();
  final KeyboardShortcut item = rowItems.removeAt(oldIndex);
  rowItems.insert(newIndex, item);

  final List<KeyboardShortcut> result = <KeyboardShortcut>[];
  var inserted = false;
  for (final KeyboardShortcut s in shortcuts) {
    if (s.row == row) {
      if (!inserted) {
        result.addAll(rowItems);
        inserted = true;
      }
    } else {
      result.add(s);
    }
  }
  if (!inserted) {
    result.addAll(rowItems);
  }
  return result;
}
```

Test in `test/models/keyboard_shortcut_meta_test.dart` or a new `test/widgets/shortcut_reorder_test.dart`:

```dart
test('reorderShortcutsInRow moves item within row only', () {
  final List<KeyboardShortcut> input = <KeyboardShortcut>[
    KeyboardShortcut.fromAction(ShortcutAction.ctrlC, row: 2),
    KeyboardShortcut.fromAction(ShortcutAction.ctrlD, row: 2),
    KeyboardShortcut.fromAction(ShortcutAction.ctrlZ, row: 2),
    KeyboardShortcut.fromAction(ShortcutAction.tabChar, row: 1),
  ];

  final List<KeyboardShortcut> output = reorderShortcutsInRow(
    shortcuts: input,
    row: 2,
    oldIndex: 0,
    newIndex: 2,
  );

  final List<ShortcutAction> row2 = output
      .where((s) => s.row == 2)
      .map((s) => s.action)
      .toList();
  expect(row2, <ShortcutAction>[
    ShortcutAction.ctrlD,
    ShortcutAction.ctrlZ,
    ShortcutAction.ctrlC,
  ]);
  expect(output.where((s) => s.row == 1).single.action, ShortcutAction.tabChar);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_reorder_test.dart`

Expected: FAIL — helper not defined.

- [ ] **Step 3: Implement helper and call it from `_onReorderItem`**

```dart
void _onReorderItem(int oldIndex, int newIndex) {
  setState(() {
    _shortcuts = reorderShortcutsInRow(
      shortcuts: _shortcuts,
      row: _selectedRow,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  });
}
```

Remove the old `[...otherRowShortcuts, ...rowShortcuts]` reconstruction (it shoved the active row to the end of the full list and made multi-row ordering brittle).

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/widgets/shortcut_reorder_test.dart test/widgets/shortcut_editor_test.dart test/models/keyboard_shortcut_meta_test.dart
flutter analyze
```

Expected: all PASS / no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_reorder_test.dart
git commit -m "fix(shortcuts): reorder within row without scrambling other rows"
```

---

### Task 5: Manual verification + full quality gate

**Files:**
- None (verification only)

- [ ] **Step 1: Full analyze + test**

```bash
flutter analyze
flutter test
```

Expected: clean analyze; all tests green. Ignore pre-existing `assets/` missing warning if present.

- [ ] **Step 2: Manual Android checks**

1. Settings → Keyboard Shortcuts → Edit shortcuts.
2. Select Ctrl row → Add → pick `Ctrl+A — Start of line` → Apply → see real label (not "New").
3. Drag via the left handle to reorder; Save; reopen editor and confirm order persisted.
4. Tap an existing tile → change action → Apply → Save → confirm bar/chip behavior on a connected session for control chars.
5. Reset restores defaults.

- [ ] **Step 3: Final commit if any polish remained**

```bash
git add -A
git commit -m "chore(shortcuts): polish configure-shortcuts fix"
```

Only if there are leftover changes; otherwise skip.

---

## Self-Review

1. **Spec coverage:** Add real shortcut — Tasks 1+3. Drag sort — Tasks 2+4. Persist — existing `updateShortcuts` path, exercised after Save. Nested ListView / wrong pop — Task 2.
2. **Placeholder scan:** No TBD/TODO steps; code and commands are concrete.
3. **Type consistency:** `shortcutActionMeta` / `ShortcutActionMeta` / `KeyboardShortcut.fromAction` / `showShortcutEditor` / `reorderShortcutsInRow` / `debugSetShortcutsForTest` names match across tasks.

## Out of scope

- Recording arbitrary OS key chords
- Per-profile shortcut sets
- Changing how `KeyboardShortcutBar` renders chips (beyond consuming updated data)

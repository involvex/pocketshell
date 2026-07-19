# Configure Shortcuts Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Configure Shortcuts support choosing a real action when adding/editing a shortcut, and make drag-to-reorder work reliably on Android.

**Architecture:** Keep persistence in `SettingsProvider.updateShortcuts`. Fix the editor UI in `shortcut_editor.dart` by adding an action-picker dialog (same pattern as `snippet_manager.dart`) and wiring real `ReorderableDragStartListener` handles. Add a small action catalog on `KeyboardShortcut` so label/description/charCode stay consistent with `ShortcutAction`.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Provider, `shared_preferences` via `ConfigService`, `flutter_test`.

## Global Constraints

- Prefer single quotes; declare return types on every method/function.
- Guard `BuildContext` after `await` with `if (!mounted) return`.
- Persistence must go through `SettingsProvider` → `ConfigService` (never call SharedPreferences from widgets).
- `ShortcutAction` remains the source of truth for behavior; `charCode` is required for ctrl/tab character sends.
- Do not rename package id (`ssh_app`) or display name (`PocketShell`).
- Run `flutter analyze` and `flutter test` before each commit; keep `analysis_options.yaml` satisfied.
- Primary target is Android (nested scroll + long-press drag are the main reorder pitfalls).

## Root Cause Findings (investigation complete)

### Bug A — Add creates dead "New" / "New Shortcut" tiles

In `lib/widgets/shortcut_editor.dart`:

```dart
void _addShortcut() {
  final newShortcut = KeyboardShortcut(
    label: 'New',
    description: 'New Shortcut',
    action: ShortcutAction.newConnection, // always App "new connection"
    row: _selectedRow,
  );
  setState(() => _shortcuts.add(newShortcut));
}
```

`_ShortcutTile` only renders static `Text(shortcut.label)` / `Text(shortcut.description)`. It accepts `onLabelChanged` but **never calls it** — no `TextField`, no action dropdown, no edit dialog. Saving persists placeholders that always fire `ShortcutAction.newConnection` (and have `charCode: null`, so Ctrl-row taps do nothing useful).

### Bug B — Drag-to-reorder appears broken

Three compounding issues:

1. **Decorative handle:** `_ShortcutTile` shows `Icons.drag_handle` in `leading`, but it is **not** wrapped in `ReorderableDragStartListener`. Users drag the icon; nothing starts.
2. **Mobile default is long-press:** With `buildDefaultDragHandles: true` on Android, Flutter wraps the whole item in `ReorderableDelayedDragStartListener` (long-press). Immediate drag fails.
3. **Nested scrollables:** `SettingsScreen` body is a `ListView` → `ExpansionTile` → `ShortcutEditor` (`ReorderableListView` at 75% screen height). The parent `ListView` competes for vertical drag gestures, so even long-press reorder is flaky.

`onReorderItem` itself is correct for Flutter 3.41+ (replaces deprecated `onReorder`). The reorder callback logic is mostly fine; the gesture plumbing and nested scroll are the failure points.

### Bug C — Save closes Settings unexpectedly

`_save()` calls `Navigator.pop(context)` after `updateShortcuts`. The editor is embedded inside Settings (`ExpansionTile` children), not pushed as a route, so Save pops the entire Settings screen instead of confirming in place. Fix: remove the pop; optionally show a SnackBar (`Shortcuts saved`).

### Bug D — Oversized nested viewport

`ShortcutEditor` forces `height: MediaQuery.size.height * 0.75` inside the expansion tile, which worsens nested scrolling. Prefer `shrinkWrap: true` on the reorder list (or a modest max height) so Settings can scroll as one surface.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/models/keyboard_shortcut.dart` | Action catalog: display name, default label, default description, default charCode per `ShortcutAction` |
| `lib/widgets/shortcut_editor.dart` | Editor UI: add/edit dialog, real drag handles, nested-scroll-safe list |
| `test/models/keyboard_shortcut_catalog_test.dart` | Unit tests for action catalog helpers |
| `test/widgets/shortcut_editor_test.dart` | Widget tests for add/edit and reorder |

No provider API changes required — `updateShortcuts` / `resetShortcuts` already correct.

---

### Task 1: Action catalog on `KeyboardShortcut`

**Files:**
- Modify: `lib/models/keyboard_shortcut.dart`
- Test: `test/models/keyboard_shortcut_catalog_test.dart`

**Interfaces:**
- Consumes: existing `ShortcutAction` enum and `KeyboardShortcut` fields
- Produces:
  - `static String displayNameFor(ShortcutAction action)`
  - `static String defaultLabelFor(ShortcutAction action)`
  - `static String defaultDescriptionFor(ShortcutAction action)`
  - `static int? defaultCharCodeFor(ShortcutAction action)`
  - `static KeyboardShortcut createForAction(ShortcutAction action, {required int row, String? id})`
  - `static List<ShortcutAction> actionsForRow(int row)` — App (0) / Terminal (1) / Ctrl (2) filtered lists

- [ ] **Step 1: Write the failing test**

Create `test/models/keyboard_shortcut_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/keyboard_shortcut.dart';

void main() {
  group('KeyboardShortcut action catalog', () {
    test('createForAction fills ctrl defaults', () {
      final KeyboardShortcut shortcut = KeyboardShortcut.createForAction(
        ShortcutAction.ctrlD,
        row: 2,
      );

      expect(shortcut.label, 'Ctrl+D');
      expect(shortcut.description, 'EOF');
      expect(shortcut.action, ShortcutAction.ctrlD);
      expect(shortcut.charCode, 4);
      expect(shortcut.row, 2);
      expect(shortcut.id, isNotEmpty);
    });

    test('actionsForRow returns row-appropriate actions', () {
      expect(
        KeyboardShortcut.actionsForRow(0),
        containsAll(<ShortcutAction>[
          ShortcutAction.newConnection,
          ShortcutAction.profiles,
          ShortcutAction.discovery,
          ShortcutAction.keys,
        ]),
      );
      expect(
        KeyboardShortcut.actionsForRow(2),
        contains(ShortcutAction.ctrlC),
      );
      expect(
        KeyboardShortcut.actionsForRow(2),
        isNot(contains(ShortcutAction.newConnection)),
      );
    });

    test('defaultCharCodeFor returns null for non-control actions', () {
      expect(
        KeyboardShortcut.defaultCharCodeFor(ShortcutAction.profiles),
        isNull,
      );
      expect(
        KeyboardShortcut.defaultCharCodeFor(ShortcutAction.ctrlV),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/keyboard_shortcut_catalog_test.dart`

Expected: FAIL — `createForAction` / `actionsForRow` not defined.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/models/keyboard_shortcut.dart` (after `actionName` getter, before `copyWith`):

```dart
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
```

Optionally refactor `defaults` to call `createForAction` so defaults and the catalog cannot drift — preferred if it stays short:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/keyboard_shortcut_catalog_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/keyboard_shortcut.dart test/models/keyboard_shortcut_catalog_test.dart
git commit -m "feat(shortcuts): add action catalog helpers for editor"
```

---

### Task 2: Add/edit shortcut dialog (fix Bug A)

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Test: `test/widgets/shortcut_editor_test.dart`

**Interfaces:**
- Consumes: `KeyboardShortcut.createForAction`, `actionsForRow`, `displayNameFor`, `defaultLabelFor`, `defaultDescriptionFor`
- Produces: `_showShortcutDialog` that returns a configured `KeyboardShortcut` (or updates existing); `_addShortcut` opens dialog instead of appending placeholders; tile tap opens edit dialog

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/shortcut_editor_test.dart` with a minimal harness. Stub `SettingsProvider` by constructing a real one after faking prefs, **or** wrap with a lightweight fake:

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
        home: Scaffold(body: ShortcutEditor()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Add opens dialog and applies selected action', (tester) async {
    await _pumpEditor(tester);

    // Switch to Ctrl row (selected index 2)
    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add Shortcut'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ShortcutAction>), findsOneWidget);

    // Pick Ctrl+L from dropdown (implementation may use displayNameFor)
    await tester.tap(find.byType(DropdownButtonFormField<ShortcutAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ctrl+L (Clear)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+L'), findsWidgets);
    expect(find.text('Clear'), findsWidgets);
    expect(find.text('New Shortcut'), findsNothing);
  });
}
```

If `ConfigService.init` / prefs setup in this project differs, mirror the pattern used in existing provider tests (search `ConfigService.init` under `test/`). Prefer the simplest working harness over inventing a new one.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL — Add does not open a dialog / "Add Shortcut" not found.

- [ ] **Step 3: Implement dialog + wire Add/Edit**

Replace `_addShortcut` and `_ShortcutTile` usage in `lib/widgets/shortcut_editor.dart`.

Key pieces to add/replace:

```dart
Future<void> _addShortcut() async {
  final KeyboardShortcut? created = await _showShortcutDialog(
    title: 'Add Shortcut',
    initial: null,
  );
  if (created == null || !mounted) return;
  setState(() => _shortcuts.add(created));
}

Future<void> _editShortcut(KeyboardShortcut shortcut) async {
  final KeyboardShortcut? updated = await _showShortcutDialog(
    title: 'Edit Shortcut',
    initial: shortcut,
  );
  if (updated == null || !mounted) return;
  setState(() {
    final int idx = _shortcuts.indexWhere((s) => s.id == shortcut.id);
    if (idx >= 0) {
      _shortcuts[idx] = updated;
    }
  });
}

Future<KeyboardShortcut?> _showShortcutDialog({
  required String title,
  required KeyboardShortcut? initial,
}) async {
  final List<ShortcutAction> actions =
      KeyboardShortcut.actionsForRow(_selectedRow);
  ShortcutAction selected = initial?.action ?? actions.first;
  final TextEditingController labelController = TextEditingController(
    text: initial?.label ?? KeyboardShortcut.defaultLabelFor(selected),
  );
  final TextEditingController descriptionController = TextEditingController(
    text: initial?.description ??
        KeyboardShortcut.defaultDescriptionFor(selected),
  );

  final KeyboardShortcut? result = await showDialog<KeyboardShortcut>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<ShortcutAction>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Action'),
                    items: actions
                        .map(
                          (ShortcutAction a) => DropdownMenuItem(
                            value: a,
                            child: Text(KeyboardShortcut.displayNameFor(a)),
                          ),
                        )
                        .toList(),
                    onChanged: (ShortcutAction? value) {
                      if (value == null) return;
                      setDialogState(() {
                        selected = value;
                        labelController.text =
                            KeyboardShortcut.defaultLabelFor(value);
                        descriptionController.text =
                            KeyboardShortcut.defaultDescriptionFor(value);
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
                  final String label = labelController.text.trim();
                  final String description =
                      descriptionController.text.trim();
                  if (label.isEmpty || description.isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    KeyboardShortcut.createForAction(
                      selected,
                      row: _selectedRow,
                      id: initial?.id,
                      label: label,
                      description: description,
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

  labelController.dispose();
  descriptionController.dispose();
  return result;
}
```

Update `_ShortcutTile`:

- Remove unused `onLabelChanged`.
- Add `VoidCallback onEdit` and `int index` (for drag listener in Task 3).
- Make the `ListTile`/`InkWell` call `onEdit` on tap (not on the delete button).

Wire in `itemBuilder`:

```dart
return _ShortcutTile(
  key: ValueKey(shortcut.id),
  index: index,
  shortcut: shortcut,
  onDelete: () => _removeShortcut(shortcut),
  onEdit: () => _editShortcut(shortcut),
);
```

Use `DropdownButtonFormField.value` instead of `initialValue` if the project's Flutter version / analyzer prefers `value` (3.47 may warn on one or the other — follow analyzer).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: PASS

Also run: `flutter analyze lib/widgets/shortcut_editor.dart lib/models/keyboard_shortcut.dart`

Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_editor_test.dart
git commit -m "fix(shortcuts): add action picker dialog for new/edit shortcuts"
```

---

### Task 3: Fix drag-to-reorder (fix Bug B)

**Files:**
- Modify: `lib/widgets/shortcut_editor.dart`
- Modify: `test/widgets/shortcut_editor_test.dart`

**Interfaces:**
- Consumes: Flutter `ReorderableDragStartListener`, existing `_onReorderItem`
- Produces: Immediate drag from the leading handle; nested-scroll-safe list; order preserved in `_shortcuts` until Save

- [ ] **Step 1: Write the failing reorder test**

Append to `test/widgets/shortcut_editor_test.dart`:

```dart
testWidgets('drag handle reorders shortcuts within the selected row',
    (tester) async {
  await _pumpEditor(tester);

  await tester.tap(find.text('Ctrl'));
  await tester.pumpAndSettle();

  // Default Ctrl order starts with Ctrl+C then Ctrl+D (see KeyboardShortcut.defaults)
  final Finder firstLabel = find.text('Ctrl+C');
  final Finder secondLabel = find.text('Ctrl+D');
  expect(firstLabel, findsOneWidget);
  expect(secondLabel, findsOneWidget);

  final Offset firstCenter = tester.getCenter(firstLabel);
  final Offset secondCenter = tester.getCenter(secondLabel);

  // Drag via the ReorderableDragStartListener icon for index 0
  final Finder handles = find.byIcon(Icons.drag_handle);
  expect(handles, findsWidgets);

  await tester.drag(handles.first, Offset(0, secondCenter.dy - firstCenter.dy));
  await tester.pumpAndSettle();

  // After reorder, Ctrl+D should appear above Ctrl+C in the list.
  final double dyD = tester.getTopLeft(find.text('Ctrl+D')).dy;
  final double dyC = tester.getTopLeft(find.text('Ctrl+C')).dy;
  expect(dyD < dyC, isTrue);
});
```

If the test harness still has parent scroll interference, pump `ShortcutEditor` alone in `MaterialApp` (already done in `_pumpEditor`) — that isolates reorder from `SettingsScreen`'s `ListView`. Still implement the production nested-scroll fix below so Settings works on device.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/shortcut_editor_test.dart`

Expected: FAIL or flaky — decorative handle does not start reorder.

- [ ] **Step 3: Wire real drag handles + nested scroll safety**

In `ShortcutEditor.build`, update the list:

```dart
Expanded(
  child: ReorderableListView.builder(
    buildDefaultDragHandles: false,
    primary: false,
    physics: const ClampingScrollPhysics(),
    itemCount: _currentRowShortcuts.length,
    onReorderItem: _onReorderItem,
    itemBuilder: (context, index) {
      final KeyboardShortcut shortcut = _currentRowShortcuts[index];
      return _ShortcutTile(
        key: ValueKey(shortcut.id),
        index: index,
        shortcut: shortcut,
        onDelete: () => _removeShortcut(shortcut),
        onEdit: () => _editShortcut(shortcut),
      );
    },
  ),
),
```

Update `_ShortcutTile`:

```dart
class _ShortcutTile extends StatelessWidget {
  final int index;
  final KeyboardShortcut shortcut;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ShortcutTile({
    required this.index,
    required this.shortcut,
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

Notes:

- Remove the duplicate `key` on the inner `Card` (key stays on `_ShortcutTile` only).
- Keep `_onReorderItem` as-is for Flutter 3.47 `onReorderItem` (index already adjusted; do **not** subtract 1).
- Optional Settings polish (same PR if quick): when embedding in `settings_screen.dart`, leave `ShortcutEditor` as-is; `primary: false` + explicit drag handle is enough. Do **not** change Settings layout unless reorder still fails on device.

Also fix Bugs C and D in the same edit:

1. Change `_save` to **not** pop Settings:

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

2. Remove the fixed `height: MediaQuery.of(context).size.height * 0.75` from the editor container. Prefer:

```dart
child: ReorderableListView.builder(
  shrinkWrap: true,
  buildDefaultDragHandles: false,
  primary: false,
  physics: const NeverScrollableScrollPhysics(),
  // ...
)
```

When using `shrinkWrap: true` + `NeverScrollableScrollPhysics`, drop the wrapping `Expanded` and let the Settings `ListView` own scrolling. Keep a reasonable `ConstrainedBox(maxHeight: …)` only if the list becomes awkwardly long.

If reorder still fights the parent `ListView` on device after the above, wrap `ShortcutEditor`'s root in:

```dart
NotificationListener<ScrollNotification>(
  onNotification: (ScrollNotification n) => true, // absorb
  child: /* existing Material/Container */,
)
```

Only add the notification absorber if still needed after manual Android check — YAGNI otherwise.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
flutter test test/widgets/shortcut_editor_test.dart test/models/keyboard_shortcut_catalog_test.dart
flutter analyze
```

Expected: All PASS / No issues.

Manual Android check (device or emulator):

1. Settings → Configure Shortcuts → Ctrl row
2. Drag the `=` handle on `Ctrl+D` above `Ctrl+C` — order should move immediately (no long-press required)
3. Tap **Add** → pick `Ctrl+A` → **Apply** — tile shows `Ctrl+A`, not `New`
4. Tap the new tile → edit label → **Apply**
5. **Save** → reopen editor — order and custom shortcut persist
6. **Reset** restores defaults

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/shortcut_editor.dart test/widgets/shortcut_editor_test.dart
git commit -m "fix(shortcuts): enable drag-handle reorder in shortcut editor"
```

---

### Task 4: Final verification

**Files:**
- None (verification only)

- [ ] **Step 1: Full quality gate**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: analyze clean (ignore pre-existing `assets/` missing warning); all tests pass.

- [ ] **Step 2: Commit any leftover formatting only if analyze/format changed files**

```bash
git status
# if dart format touched files:
git add -A
git commit -m "chore: format shortcut editor fix"
```

- [ ] **Step 3: Push branch**

```bash
git push -u origin cursor/fix-configure-shortcuts-8a40
```

---

## Self-Review

1. **Spec coverage:** Add applies real shortcut ✓ — Task 2. Drag sort works ✓ — Task 3. Catalog prevents label/action drift ✓ — Task 1. Persistence via existing Save ✓ — unchanged provider path. Save no longer pops Settings ✓ — Task 3. Nested height/scroll fixed ✓ — Task 3.
2. **Placeholder scan:** No TBD/TODO steps; concrete code and commands included.
3. **Type consistency:** `createForAction` / `actionsForRow` / `displayNameFor` names match across Task 1–2.

## Out of Scope (YAGNI)

- Custom freeform key sequences beyond existing `ShortcutAction` enum
- Per-shortcut custom charCode editor (catalog defaults are enough)
- Redesigning Settings layout / moving editor to a bottom sheet
- iOS-specific polish beyond shared Flutter drag APIs

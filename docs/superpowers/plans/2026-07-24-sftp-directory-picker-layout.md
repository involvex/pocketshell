# SFTP Directory Picker Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the cramped, broken layout of the Agents tab “Select Project Directory” SFTP picker on phone-width screens so path, drive selector, toolbar, folder list, and action buttons are readable, aligned, and tappable.

**Architecture:** Keep shared SFTP logic in `SftpController` / `SftpEntryList`. Make `SftpBrowserHeader` responsive: stack path, drive, and toolbar vertically below ~480 logical px instead of squeezing title + five icon buttons into one row. Replace the picker’s `AlertDialog` shell with a near-full-screen `Dialog` that owns its own title bar and bottom action bar, giving the list predictable height and preventing overlap with Cancel/Select.

**Tech Stack:** Flutter, Material 3, existing `SftpController` / `SftpBrowserHeader` / `SftpEntryList`, `flutter_test` widget tests at 360×800 logical px.

## Global Constraints

- Primary target: **Android client → Windows hosts** (drive letters `C:/`, etc.).
- Agents directory pick must use the **same** listing/navigation core as the Client SFTP browser (`SftpController`, shared widgets).
- Persist user prefs only through **ConfigService** (no direct `shared_preferences` in widgets).
- Use `package:` imports; satisfy `strict-casts` / `strict-raw-types` and `analysis_options.yaml`.
- Run `flutter analyze` and `flutter test` after each task; commit after each task.
- Do not reintroduce local `FilePicker` for agent directory selection.
- Minimize scope: layout/responsiveness only — no new SFTP features.

## Layout diagnosis (from screenshot + code)

| Symptom | Root cause |
|---------|------------|
| “Remote files” renders vertically (`R`/`e`/`m`/…) | `SftpBrowserHeader` puts title+path in `Expanded` beside 5+ `IconButton`s inside narrow `AlertDialog` content (~280–320 px usable width). |
| Toolbar icons tiny and misaligned | Same single `Row`; icons win horizontal space; drive dropdown sits on a second row with different left inset. |
| Folder list crowds/overlaps Cancel | `AlertDialog` `actions` sit outside `Expanded` list; no bottom safe padding on `ListView`. |
| Redundant chrome | Dialog title “Select Project Directory” **and** header “Remote files”. |
| Unnecessary per-folder ⋮ menu in picker | `SftpEntryList` shows `more_vert` even when `directoriesOnly: true`. |

## File map

| File | Change |
|------|--------|
| Modify: `lib/widgets/sftp/sftp_browser_header.dart` | Responsive stacked layout; optional `showSectionTitle`; compact toolbar |
| Modify: `lib/widgets/sftp/sftp_entry_list.dart` | Hide trailing actions in `directoriesOnly`; optional `listBottomPadding` |
| Modify: `lib/widgets/sftp_directory_picker.dart` | Near-full-screen dialog shell; wire compact header |
| Create: `test/widgets/sftp_browser_header_layout_test.dart` | Regression tests at phone width |
| Create: `test/widgets/sftp_directory_picker_layout_test.dart` | Picker shell + no vertical-letter title |

---

### Task 1: Responsive `SftpBrowserHeader`

**Files:**
- Modify: `lib/widgets/sftp/sftp_browser_header.dart`
- Create: `test/widgets/sftp_browser_header_layout_test.dart`

**Interfaces:**
- Consumes: existing `SftpBrowserHeader` constructor callbacks (unchanged signatures).
- Produces:
  - New optional param `showSectionTitle` (`bool`, default `true`).
  - New optional param `compactWidthBreakpoint` (`double`, default `480`).
  - Internal `_SftpHeaderToolbar` widget reused by standard and compact layouts.
  - `bool _isCompactLayout(double maxWidth)` — true when `maxWidth < compactWidthBreakpoint`.

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/sftp_browser_header_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/remote_fs_sort.dart';
import 'package:ssh_app/widgets/sftp/sftp_browser_header.dart';

void _setPhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrapHeader({required bool showSectionTitle}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: SftpBrowserHeader(
          currentPath: r'C:\Users\dev\projects',
          drives: const <String>['C'],
          filterTerm: '',
          sortField: RemoteFsSortField.name,
          sortAscending: true,
          showSectionTitle: showSectionTitle,
          onCopyPath: () async {},
          onDriveSelected: (_) async {},
          onFilterChanged: (_) {},
          onSortChanged: (_, __) async {},
          onRefresh: () async {},
          onCreateDirectory: (_) async {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('compact layout does not render vertical Remote files letters',
      (WidgetTester tester) async {
    _setPhoneSurface(tester);
    await tester.pumpWidget(_wrapHeader(showSectionTitle: false));
    await tester.pumpAndSettle();

    expect(find.text('Remote files'), findsNothing);

    final RenderBox pathBox =
        tester.renderObject<RenderBox>(find.text(r'C:\Users\dev\projects'));
    expect(pathBox.size.width, greaterThan(200));
  });

  testWidgets('standard layout keeps section title on wide surface',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SftpBrowserHeader(
              currentPath: r'C:\Users\dev\projects',
              drives: const <String>['C'],
              filterTerm: '',
              sortField: RemoteFsSortField.name,
              sortAscending: true,
              onCopyPath: () async {},
              onDriveSelected: (_) async {},
              onFilterChanged: (_) {},
              onSortChanged: (_, __) async {},
              onRefresh: () async {},
              onCreateDirectory: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remote files'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/sftp_browser_header_layout_test.dart`
Expected: FAIL — `showSectionTitle` parameter not defined; layout still breaks at 320 px.

- [ ] **Step 3: Implement responsive header**

In `lib/widgets/sftp/sftp_browser_header.dart`:

1. Add fields to constructor:

```dart
final bool showSectionTitle;
final double compactWidthBreakpoint;

// defaults in constructor:
this.showSectionTitle = true,
this.compactWidthBreakpoint = 480,
```

2. Wrap the existing `Padding` → `Column` body in `LayoutBuilder`:

```dart
@override
Widget build(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  // ... selectedDrive, hasDriveSelection, showSecondaryRow ...

  return Material(
    color: theme.colorScheme.surfaceContainerLow,
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < widget.compactWidthBreakpoint;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: compact
              ? _buildCompactHeader(
                  theme: theme,
                  selectedDrive: selectedDrive,
                  hasDriveSelection: hasDriveSelection,
                  showSecondaryRow: showSecondaryRow,
                )
              : _buildStandardHeader(
                  theme: theme,
                  selectedDrive: selectedDrive,
                  hasDriveSelection: hasDriveSelection,
                  showSecondaryRow: showSecondaryRow,
                ),
        );
      },
    ),
  );
}
```

3. Extract `_buildToolbar()` returning the existing icon row (copy, search toggle, sort menu, refresh, new folder, upload menu) — unchanged behavior.

4. **`_buildStandardHeader`**: move current `Row` + secondary `Row` implementation here unchanged except:
   - Wrap title `Text('Remote files')` in `if (widget.showSectionTitle)`.

5. **`_buildCompactHeader`**: vertical stack:

```dart
Widget _buildCompactHeader({ ... }) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (widget.showSectionTitle)
        Text('Remote files', style: theme.textTheme.titleMedium),
      Text(
        widget.currentPath,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (hasDriveSelection) _buildDriveDropdown(selectedDrive),
      if (hasDriveSelection) const SizedBox(height: 8),
      if (_showSearch) ...<Widget>[
        _buildSearchField(),
        const SizedBox(height: 8),
      ],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildToolbar(),
      ),
    ],
  );
}
```

6. Extract `_buildDriveDropdown` and `_buildSearchField` from the existing secondary row so both layouts share them.

7. In compact mode, **do not** place path text in a `Row` beside toolbar icons.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/sftp_browser_header_layout_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/sftp/sftp_browser_header.dart test/widgets/sftp_browser_header_layout_test.dart
git commit -m "fix(sftp): responsive browser header for narrow pickers"
```

---

### Task 2: Directory-only list polish

**Files:**
- Modify: `lib/widgets/sftp/sftp_entry_list.dart`
- Modify: `test/widgets/sftp_directory_picker_layout_test.dart` (create file with one failing test stub)

**Interfaces:**
- Consumes: existing `SftpEntryList` API.
- Produces:
  - New optional `listBottomPadding` (`double`, default `0`).
  - When `directoriesOnly == true`, no trailing `IconButton` / `more_vert` on folder tiles.

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/sftp_directory_picker_layout_test.dart` (partial — expanded in Task 3):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/remote_fs_entry.dart';
import 'package:ssh_app/widgets/sftp/sftp_entry_list.dart';

void main() {
  testWidgets('directoriesOnly hides per-entry overflow menu',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SftpEntryList(
            entries: const <RemoteFsEntry>[
              RemoteFsEntry(
                name: 'projects',
                isDirectory: true,
                size: 0,
              ),
            ],
            currentPath: r'C:\',
            loading: false,
            directoriesOnly: true,
            onOpenEntry: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/sftp_directory_picker_layout_test.dart`
Expected: FAIL — `more_vert` still found.

- [ ] **Step 3: Implement list changes**

In `lib/widgets/sftp/sftp_entry_list.dart`:

1. Add constructor param:

```dart
final double listBottomPadding;
// default:
this.listBottomPadding = 0,
```

2. In `ListView.builder`, add padding:

```dart
ListView.builder(
  padding: EdgeInsets.only(bottom: listBottomPadding),
  itemCount: visibleEntries.length,
  ...
)
```

3. In `_EntryTile.build`, change trailing condition:

```dart
trailing: canShowMenu && !selectionMode && !directoriesOnly
    ? Row(
        ...
      )
    : null,
```

4. In `_EntryTile`, skip long-press action sheet when `directoriesOnly` (optional but cleaner):

```dart
onLongPress: canShowMenu && !directoriesOnly
    ? () async { ... }
    : null,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/sftp_directory_picker_layout_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/sftp/sftp_entry_list.dart test/widgets/sftp_directory_picker_layout_test.dart
git commit -m "fix(sftp): simplify directory-only entry list"
```

---

### Task 3: Redesign `SftpDirectoryPicker` shell

**Files:**
- Modify: `lib/widgets/sftp_directory_picker.dart`
- Modify: `test/widgets/sftp_directory_picker_layout_test.dart`

**Interfaces:**
- Consumes: `SftpBrowserHeader(showSectionTitle: false)`, `SftpEntryList(directoriesOnly: true, listBottomPadding: 8)`.
- Produces: `SftpDirectoryPicker` widget with same public constructor (`SSHClient client`, `String? initialPath`) and same `Navigator.pop` contract.

- [ ] **Step 1: Write the failing picker layout test**

Append to `test/widgets/sftp_directory_picker_layout_test.dart`:

```dart
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_app/widgets/sftp_directory_picker.dart';

// Add a minimal fake SSHClient is heavy; instead test the shell via
// a package-private layout helper if needed. Prefer testing presence of
// bottom bar buttons and absence of AlertDialog actions overlap:

testWidgets('picker uses bottom action bar with Select and Cancel',
    (WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  // We cannot construct SSHClient easily; skip integration here
                  // and assert via header-only shell widget extracted below.
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
});
```

Because `SSHClient` is hard to fake in a widget test, extract a **testable shell** widget in the same file:

In `lib/widgets/sftp_directory_picker.dart`, add:

```dart
/// Layout shell for directory picker surfaces (testable without SSH).
class SftpDirectoryPickerShell extends StatelessWidget {
  const SftpDirectoryPickerShell({
    required this.header,
    required this.body,
    required this.onCancel,
    required this.onSelect,
    super.key,
  });

  final Widget header;
  final Widget body;
  final VoidCallback onCancel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screen.width - 24,
        height: screen.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Select Project Directory',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            header,
            Expanded(child: body),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onSelect,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Replace the failing integration test with a shell test:

```dart
testWidgets('picker shell shows title, list region, and bottom actions',
    (WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: SftpDirectoryPickerShell(
        header: const SizedBox(height: 48, child: Text('HEADER')),
        body: ListView(children: const <Widget>[Text('folder-a')]),
        onCancel: () {},
        onSelect: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Select Project Directory'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Select'), findsOneWidget);
  expect(find.text('folder-a'), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/sftp_directory_picker_layout_test.dart`
Expected: FAIL — `SftpDirectoryPickerShell` not defined.

- [ ] **Step 3: Implement picker shell and wire state**

Refactor `_SftpDirectoryPickerState.build`:

```dart
@override
Widget build(BuildContext context) {
  return SftpDirectoryPickerShell(
    onCancel: () => Navigator.pop(context),
    onSelect: () => Navigator.pop(context, _controller.currentPath),
    header: AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return SftpBrowserHeader(
          currentPath: _controller.currentPath,
          drives: _controller.drives,
          filterTerm: _controller.filterTerm,
          sortField: _controller.sortField,
          sortAscending: _controller.sortAscending,
          showSectionTitle: false,
          onCopyPath: () async {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Path copied')),
            );
          },
          onDriveSelected: (String drive) =>
              _controller.navigateTo('$drive:/'),
          onFilterChanged: _controller.setFilter,
          onSortChanged: (RemoteFsSortField field, bool ascending) =>
              _controller.setSort(field, ascending: ascending),
          onRefresh: _controller.refresh,
          onCreateDirectory: _controller.mkdir,
        );
      },
    ),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return SftpEntryList(
          entries: _controller.visibleEntries,
          currentPath: _controller.currentPath,
          loading: _controller.loading,
          error: _controller.error,
          directoriesOnly: true,
          listBottomPadding: 8,
          onOpenEntry: _controller.openEntry,
          onRenameEntry: _controller.rename,
          onDeleteEntry: _controller.deleteEntry,
        );
      },
    ),
  );
}
```

Remove the old `AlertDialog` / `actions` / outer `title` / fixed `SizedBox(height: 0.6 * screen)` wrapper.

- [ ] **Step 4: Run tests**

Run: `flutter test test/widgets/sftp_directory_picker_layout_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Run full quality gate**

Run: `flutter analyze && flutter test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/sftp_directory_picker.dart test/widgets/sftp_directory_picker_layout_test.dart
git commit -m "fix(sftp): near-full-screen directory picker layout"
```

---

### Task 4: Manual QA on Android

**Files:** none (verification only)

- [ ] **Step 1: Build and open Agents tab on a phone or narrow emulator**

Run: `flutter run` (Android device/emulator, width ≤ 400 logical px).

- [ ] **Step 2: Open “Select project directory via SFTP”**

Verify:
- Title “Select Project Directory” appears once at top.
- Current path is horizontal (ellipsis), not letter-stacked.
- Drive dropdown spans content width and aligns with list.
- Toolbar icons are in a horizontal scroll row or wrapped — all tappable (≥ 48 dp).
- Folder list scrolls without overlapping Cancel/Select.
- Tapping a folder navigates; Select returns path; Cancel dismisses.
- Client tab full SFTP browser (`SftpBrowser`) still shows “Remote files” on wide layout and remains usable.

- [ ] **Step 3: Commit QA notes (optional)**

If any tweak needed from QA, fix and commit before PR.

---

## Self-review

**Spec coverage**

| Requirement | Task |
|-------------|------|
| Fix vertical “Remote files” text | Task 1 compact header |
| Align drive selector with list | Task 1 + Task 3 full-width column |
| Reduce wasted top space / crowding at bottom | Task 3 shell + Task 2 list padding |
| Larger touch targets | Task 1 horizontal toolbar scroll |
| Picker-specific simplification (no ⋮ on folders) | Task 2 |
| Regression tests at phone width | Tasks 1–3 |
| SFTP browser unchanged on wide screens | Task 1 `LayoutBuilder` breakpoint |

**Placeholder scan:** No TBD/TODO steps; all code and commands are concrete.

**Type consistency:** `showSectionTitle`, `listBottomPadding`, `SftpDirectoryPickerShell` names used consistently across tasks.

## Out of scope

- Changing `agents_tab.dart` `showDialog` call site (picker widget encapsulates layout).
- SFTP transfer/upload UI in picker (already absent).
- Tablet side-by-side master-detail for picker.
- Theming / hacker-mode color tweaks beyond existing tokens.

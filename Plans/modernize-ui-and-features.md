# Implementation Plan: Modernize SSH App UI and Features

Modernize the SSH app UI to Material 3 standards, add a custom 'Hacker' theme, and implement a full-screen snippet management system.

## Objective
- Upgrade to Material 3 (M3) across the app.
- Implement a "Hacker" theme (Black background, GreenAccent text).
- Create a dedicated "Snippet Manager" screen for better command snippet handling.
- Improve overall UI consistency and aesthetics.

## Key Files & Context
- `lib/providers/settings_provider.dart`: Manage theme presets and persistence.
- `lib/main.dart`: Configure `MaterialApp` with M3 and custom themes.
- `lib/screens/home_screen.dart`: Update navigation and terminal view styling.
- `lib/screens/settings_screen.dart`: Add theme preset selection.
- `lib/screens/snippet_config_screen.dart` (NEW): Full-screen management of command snippets.
- `lib/widgets/theme_picker.dart`: UI for selecting theme presets.

## Proposed Solution

### 1. State & Persistence Updates
- **`lib/providers/settings_provider.dart`**:
    - Add `AppTheme` enum: `system`, `light`, `dark`, `hacker`.
    - Update `loadSettings` and `_saveSetting` to handle the new `appTheme` preference.
- **`lib/services/config_service.dart`**: Ensure it correctly handles the new setting if needed (it uses a generic map, so it should be fine).

### 2. Material 3 & Theme Implementation
- **`lib/main.dart`**:
    - Set `useMaterial3: true` in all `ThemeData` instances.
    - Implement `ColorScheme.fromSeed` for `standardLightTheme` and `standardDarkTheme` based on `settings.accentColor`.
    - Create `hackerThemeData`:
        - `brightness: Brightness.dark`
        - `scaffoldBackgroundColor: Colors.black`
        - `primaryColor: Colors.greenAccent`
        - `colorScheme`: Custom black/green scheme.
        - `appBarTheme`: Black background, green text.
        - `textTheme`: Primarily green text where applicable.

### 3. UI Refactoring
- **`lib/screens/home_screen.dart`**:
    - Update `AppBar` to be cleaner (M3 style).
    - Ensure `TerminalView` uses colors from the current theme.
    - Add a "Snippets" entry point to the new screen.
- **`lib/widgets/theme_picker.dart`**:
    - Add a segment or toggle for the 'Hacker' theme.
    - Improve layout for M3 consistency.

### 4. Snippet Management
- **`lib/screens/snippet_config_screen.dart`**:
    - Create a new screen with a `ListView` of snippets.
    - Support search, categories, and direct "Add/Edit/Delete" actions.
    - Use M3 `Card`s and `FloatingActionButton` for adding new snippets.

## Implementation Steps

### Phase 1: State Management
1.  Update `lib/providers/settings_provider.dart` with `AppTheme` enum and logic.
2.  Update `lib/services/config_service.dart` if any specific mapping is required (unlikely but will verify).

### Phase 2: Theme & Main App
1.  Modify `lib/main.dart` to enable M3 and define the themes (Light, Dark, Hacker).
2.  Refactor `ThemePicker` in `lib/widgets/theme_picker.dart` to support the new theme selection.

### Phase 3: Home & Terminal
1.  Update `lib/screens/home_screen.dart` to adopt M3 layout and theme-aware terminal styling.
2.  Update `lib/widgets/snippet_button_panel.dart` to align with the new UI.

### Phase 4: Snippet Screen
1.  Create `lib/screens/snippet_config_screen.dart`.
2.  Wire it up in `HomeScreen` and `SettingsScreen`.
3.  Ensure CRUD operations work correctly and persist.

## Verification & Testing
- **Visual Check**: Verify M3 components (NavigationBar, Buttons, Cards) look correct.
- **Theme Switching**: Test switching between Light, Dark, System, and Hacker themes.
- **Terminal View**: Ensure the terminal colors change appropriately (especially in Hacker mode).
- **Snippet CRUD**: Add, edit, and delete snippets in the new screen and verify they appear in the terminal panel.
- **Persistence**: Restart the app and verify settings and snippets are saved.

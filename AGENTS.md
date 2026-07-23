# AGENTS.md - SSH App Development Guide

Guidelines for agents operating on this Flutter SSH application codebase.

## Project Overview

- **Type**: Flutter Desktop/Mobile Application (SSH Client)
- **State Management**: Provider
- **Persistence**: shared_preferences (via ConfigService)
- **Architecture**: Separated models, services, providers, screens, and widgets.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Run development app
flutter run

# Build for specific platforms
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows
flutter build macos        # macOS
flutter build linux        # Linux
flutter build web          # Web (if supported)
```

## Lint & Analysis

```bash
# Run static analysis (required before commits)
flutter analyze
```

## Testing

```bash
# Run all tests
flutter test

# Run tests in a specific directory
flutter test test/
```

## Release

Version lives in `pubspec.yaml` as `MAJOR.MINOR.PATCH+BUILD`. User-facing semver is shown in Settings via `package_info_plus`; display name is `kAppDisplayName` in `lib/constants/app_metadata.dart` (**PocketShell**).

```powershell
# Patch release (default): changelog bullet is the version tag (e.g. v1.0.1)
./scripts/release.ps1

# Preview bump without writing
./scripts/release.ps1 -DryRun

# Custom changelog note
./scripts/release.ps1 -Message "Fix connection timeout"

# Options: -Bump patch|minor|major, -NoPush, -SkipTests
```

Release script steps: assert clean tree → bump pubspec semver and build number → prepend `## [X.Y.Z] - date` to `CHANGELOG.md` → `flutter pub get` / `analyze` / `test` → commit `chore(release): vX.Y.Z` → annotated tag `vX.Y.Z` → push branch and tag.

## Code Style Guidelines

### Import Conventions

- Use `package:` prefix for all project imports.
- Grouping: Dart SDK -> external packages -> project imports.
- Sort alphabetically within groups.

### Naming Conventions

- **Classes**: PascalCase (e.g., `SSHProvider`).
- **Methods/Variables**: camelCase (e.g., `connectClient()`).
- **Private members**: Prefix with `_` (e.g., `_client`).
- **Constants**: `k` prefix (e.g., `kDefaultPort`).
- **Files**: snake_case (e.g., `ssh_provider.dart`).

### Type Annotations

- Explicit return types for methods.
- Prefer `final` over `var`.
- Use `const` constructors for static widgets and constant data.

## Project Structure

```text
lib/
├── models/             # Data Models (SSHProfile, SSHKey, KeyboardShortcut, Snippet)
├── services/           # Services (ConfigService, NetworkDiscoveryService, SSHKeyGenerator)
├── providers/          # State Management (SSHProvider, SettingsProvider, SnippetProvider)
├── screens/            # Main Screens (HomeScreen, SettingsScreen, SplashScreen)
├── widgets/            # Reusable Widgets (KeyManager, ProfileManager, LogViewer, forms)
└── main.dart           # App Entry Point
```

## Working with Providers

### SSHProvider
- `connectClient({required SSHProfile profile})` - Connect to a remote SSH server using a profile.
- `terminal` - The current active `Terminal` instance (xterm).
- `connectionLog` - List of strings for displaying logs in UI.

### SettingsProvider
- `themeMode` - Current application theme (Light/Dark/System).
- `accentColor` - Primary application accent color.
- `updateTheme(ThemeMode mode)` - Change app theme.

### SnippetProvider
- `snippets` - List of saved command fragments.
- `addSnippet(Snippet snippet)` - Create new snippet.

## Best Practices

1. **Always use ConfigService** for persistence. Do not call `shared_preferences` directly from widgets.
2. **Handle Async Safety**: Use `try-catch` for all SSH and network operations.
3. **Notify Listeners**: Ensure `notifyListeners()` is called in providers after state changes.
4. **UI Decoupling**: Keep business logic in providers/services; widgets should only handle display and user interaction.
5. **Clean Resources**: Always implement `dispose()` in providers to close sockets, PTYs, and timers.
6. **Strict Typing**: Maintain `strict-casts` and `strict-raw-types` compliance.

## Learned User Preferences

- Prefer a native OpenCode HTTP API UI for the Agents tab over WebView or an external browser.
- Handle agent mode switching only through `/agent` slash commands; do not add a separate agent picker UI.
- Support model and provider configuration via slash commands (`/model`, `/models`, `/connect`) plus a config sheet in the Agents tab chat toolbar.
- Use the SFTP directory browser for agent project directory selection, not the local FilePicker.
- Target home-screen quick-connect widgets at Android only; the Agent widget should connect and resume the most recently updated session.
- The local SSH Server tab was removed (it was a non-functional stub); do not reintroduce a Server tab without a real host implementation.
- Use **PocketShell** as the user-facing display name (display-only rename; keep `ssh_app` package/id unchanged).
- Primary usage is Android client connecting to **Windows** hosts for SSH and OpenCode agents.
- OpenCode config should use the connected server API (`getConfig`/`updateConfig`) plus remote import from the Windows host over SSH, not local mobile config files.
- Agents tab should use master-detail navigation on all screen sizes (hide session list when chat is open), not a side-by-side split on wide screens.

## Learned Workspace Facts

- Home navigation uses `AppTab` (Client, Agents, Logs) with an `IndexedStack`.
- OpenCode integrates through `opencode_api` and `OpenCodeConnectionService`; sessions are scoped by a `directory` query param; `getConfig`/`updateConfig` exposed for server-side config.
- `SSHProfile` includes `agentPort` (default 5000) and `useHttps`; `agentBaseUrl` builds the OpenCode URL.
- `AgentProvider` is a `ChangeNotifierProxyProvider` that routes `onLog` to `SSHProvider.addLog`.
- Agent directory path persists in ConfigService as `agent_last_directory`.
- Android widgets (`SshQuickConnectWidget`, `AgentQuickConnectWidget`) sync profiles via `WidgetProfileService` and deep-link via `sshapp://widget/ssh|agent?profileId=` through `WidgetLaunchHandler`.
- Terminal styling is centralized in `TerminalStyleBuilder` (font family, weight, style, size) and uses `google_fonts` for bold/italic variants.
- `lib/utils/agent_session_utils.dart` holds session sort helpers and `agentDirectoryScopeForConnection`.
- Agents tab uses master-detail navigation on all screen sizes with `PopScope` and Android predictive back.
- `AppLifecycleService` and `ConnectionForegroundService` keep SSH/agent sessions alive when Android is backgrounded.
- Agent chat groups consecutive same-role messages via `groupAgentMessages` in `lib/utils/agent_message_grouping.dart`; rendering uses `AgentMessageBubble` and `AgentMessagePartTile`.
- `OpenCodeRemoteConfigService` imports Windows host config over SSH from `%USERPROFILE%\.config\opencode\`; Android build uses AGP 9.0.1 with vendored `packages/home_widget`.

## Cursor Cloud specific instructions

The standard commands (`flutter pub get` / `flutter analyze` / `flutter test`) are documented in the Build/Lint/Testing sections above. Notes below cover only non-obvious caveats for the headless cloud VM.

- **Flutter SDK** is installed at `~/flutter` and on `PATH` via `~/.bashrc`. The startup update script only runs `flutter pub get`; the SDK and system libraries live in the VM snapshot.
- **Running the app:** Android is the primary product target, but this VM has no Android device. The runnable dev target here is the Linux desktop against the virtual display: `export DISPLAY=:1 && flutter run -d linux`. `flutter run -d web-server` is not viable because `flutter_pty` has no web support.
- **Linux desktop build deps** (already in the snapshot): `ninja-build`, `libgtk-3-dev`, `build-essential`, and crucially `libstdc++-14-dev`. Clang 18 selects GCC 14, so without `libstdc++-14-dev` the build fails with `/usr/bin/ld: cannot find -lstdc++`.
- **`flutter_secure_storage` throws `PlatformException(KeyringLocked)` on startup** here because the headless VM has no unlocked libsecret/GNOME keyring. This is non-fatal: the app runs normally and SSH profiles (stored via `shared_preferences`) work. Only secure-storage-backed values (e.g. the OpenCode Zen API key) are affected.
- **Pre-existing `assets/` warning:** `flutter analyze`/`test` print `asset directory 'assets/' doesn't exist` because `pubspec.yaml` lists `assets/` but the dir is absent. It is a harmless warning, not a failure.
- **Testing the SSH client E2E locally:** start a local `sshd` (`sudo /usr/sbin/sshd`), set a password for the `ubuntu` user, and connect the app's Client tab to `localhost:22`. This exercises the real SSH connect + terminal path without an external host.

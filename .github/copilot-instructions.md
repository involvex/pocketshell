# GitHub Copilot Instructions — ssh_app

Flutter-based SSH client and server application targeting desktop and mobile platforms.

## Build, Lint & Test Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in debug mode
flutter analyze          # Static analysis (run before committing)
flutter test             # Run tests (test/ directory)

flutter build apk        # Android APK
flutter build ios        # iOS
flutter build windows    # Windows desktop
flutter build macos      # macOS desktop
flutter build linux      # Linux desktop
```

> **Note:** The test suite (`test/widget_test.dart`) is currently a placeholder stub. Run `flutter analyze` as the primary quality gate.

## Architecture Overview

### Layer Flow

```
lib/
├── models/       — Plain Dart data classes (SSHProfile, SSHKey, KeyboardShortcut, Snippet)
├── services/     — Business logic / external I/O (ConfigService, SSHKeyGenerator, NetworkDiscoveryService)
├── providers/    — ChangeNotifier state managers (SSHProvider, SettingsProvider, SnippetProvider)
├── screens/      — Top-level pages (SplashScreen, HomeScreen, SettingsScreen, SnippetConfigScreen)
└── widgets/      — Reusable UI components
```

### Startup Sequence

`SplashScreen` calls `ConfigService.init()` (must happen before any ConfigService access, throws `StateError` otherwise), then navigates to `HomeScreen`. `HomeScreen.initState` calls `SSHProvider.loadConfig()`.

### State Management

Three providers are registered at app root in `main.dart` via `MultiProvider`:

| Provider | Responsibility |
|----------|---------------|
| `SSHProvider` | SSH client/server connection, xterm `Terminal` instance, profiles, connection log, network scan |
| `SettingsProvider` | Theme (`AppTheme` enum), accent color, keyboard shortcuts |
| `SnippetProvider` | Command snippet CRUD |

All state mutations must call `notifyListeners()` after completing.

### Persistence Pattern

**All persistence goes through `ConfigService`** — a static wrapper around `shared_preferences`. Never call SharedPreferences directly from widgets or providers.

SharedPreferences keys:
- `ssh_profiles` — JSON list of `SSHProfile`
- `last_session` — last connected profile ID
- `app_settings` — theme + accent color
- `ssh_keys` — JSON list of `SSHKey`
- `snippets` — JSON list of `Snippet`

### SSH + Terminal Wiring

- `SSHProvider.terminal` is an xterm `Terminal` instance; reset to a new instance on disconnect.
- SSH session stdout/stderr pipe into `terminal.write()`.
- `terminal.onOutput` sends keystrokes back to `_session!.stdin`.
- A startup command (from `SSHProfile.startupCommand`) is sent via `_session!.stdin` using `\r` as line terminator, after a 3-second wait for first stdout.
- `connectionLog` is a user-visible list capped at 100 entries (oldest pruned on overflow). Timestamps format: `HH:MM:SS`.

## Model Conventions

- All models use `uuid` for IDs: `id = id ?? const Uuid().v4()` — pass an explicit `id` only when deserialising.
- Serialisation: `toJson()` returns `Map<String, dynamic>`, `fromJson()` is a factory constructor.
- `SSHKeyType` is serialised as its **integer index** (`keyType.index`), not its name.
- `KeyboardShortcut.row` groups buttons into display rows in the shortcut bar (row 0 = navigation, 1 = arrows, 2 = ctrl combos).
- `Snippet` and `KeyboardShortcut` both have a `static List<T> get defaults` for first-run initialisation.
- All models implement `copyWith()`.

## Theme System

`AppTheme` enum values: `system`, `light`, `dark`, `hacker`.  
`hacker` uses `ThemeMode.dark` but overrides colours to a black/green terminal aesthetic.  
Stored as string in settings under the `appTheme` key.  
Accent colours are named (`blue`, `green`, `purple`, `orange`, `red`).

## Coding Conventions

### Linting (strict — enforced by `analysis_options.yaml`)

- `strict-casts: true` and `strict-raw-types: true` — explicit casts required when narrowing types.
- `always_declare_return_types` — every method/function must have an explicit return type.
- `prefer_single_quotes` — use `'...'` not `"..."`.
- `prefer_const_constructors` / `prefer_const_declarations` — use `const` wherever possible.
- `prefer_final_fields` / `prefer_final_locals` — use `final` unless mutation is needed.
- `use_build_context_synchronously` — never use `BuildContext` across async gaps without a `mounted` check.
- `cancel_subscriptions` / `close_sinks` — always cancel StreamSubscriptions and close StreamControllers in `dispose()`.
- `unawaited_futures` — mark intentionally unawaited calls with `// ignore: unawaited_futures`.

### Imports

Group order: Dart SDK → external packages → project imports (`package:ssh_app/...`). Sort alphabetically within each group.

### Naming

- Classes: `PascalCase` (e.g. `SSHProvider`)
- Methods/variables: `camelCase` (e.g. `connectClient`)
- Private members: `_` prefix (e.g. `_client`)
- Constants: `k` prefix (e.g. `kDefaultPort`)
- Files: `snake_case` (e.g. `ssh_provider.dart`)

### Async Safety

Wrap all SSH and network calls in `try-catch`. After any `await`, guard `BuildContext` usage with `if (!mounted) return`.

### Logging

Use `SSHProvider.addLog(String message)` for all user-visible events (connection steps, errors, server status). This applies the `HH:MM:SS` timestamp and enforces the 100-entry cap automatically.

### Provider Access

Use `Provider.of<T>(context, listen: false)` for one-shot reads in callbacks. Use `Consumer<T>` or `context.watch<T>()` in build methods that need to rebuild.

### Dispose

All providers and `StatefulWidget`s that hold subscriptions, timers, or streams must override `dispose()` to release them.

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App root; MultiProvider registration; all theme definitions including hacker theme |
| `lib/providers/ssh_provider.dart` | Core SSH state; client connection, server, terminal, logs, profiles |
| `lib/providers/settings_provider.dart` | AppTheme enum, accent colors, keyboard shortcuts |
| `lib/providers/snippet_provider.dart` | Snippet CRUD via ConfigService |
| `lib/services/config_service.dart` | Single persistence gateway; must call `ConfigService.init()` at startup |
| `lib/screens/splash_screen.dart` | Initialises ConfigService; entry point before HomeScreen |
| `lib/screens/home_screen.dart` | Main UI; keyboard shortcuts (Ctrl+N/P/D/K); terminal display |
| `analysis_options.yaml` | Strict lint rules; must remain satisfied after any change |

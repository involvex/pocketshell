# Getting Started

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>= 3.2.0`
- Android SDK for APK builds (Java 17)

## Install and run

```bash
git clone https://github.com/involvex/pocketshell.git
cd pocketshell
flutter pub get
flutter run
```

## Quality checks

```bash
flutter analyze
flutter test
```

## Build targets

=== "Android"

    ```bash
    flutter build apk --release
    ```

    Output: `build/app/outputs/flutter-apk/app-release.apk`

=== "Windows"

    ```bash
    flutter build windows
    ```

=== "Linux"

    ```bash
    flutter build linux
    ```

## Project layout

```text
lib/
├── models/     # SSHProfile, SSHKey, Snippet, KeyboardShortcut
├── services/   # ConfigService, network discovery, backup
├── providers/  # SSHProvider, SettingsProvider, SnippetProvider, AgentProvider
├── screens/    # Home, Settings, Splash
└── widgets/    # Terminal, profiles, keys, agent chat
```

Persistence goes through `ConfigService` (`shared_preferences`). Call
`ConfigService.init()` during startup before any other config access.

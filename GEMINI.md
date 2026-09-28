# GEMINI.md

## Project Overview

**ssh_app** is a comprehensive Flutter-based application offering both SSH client and server functionalities across mobile and desktop platforms. It provides a full-featured terminal emulator for remote access and a local SSH server for device shell access.

### Main Technologies

- **Flutter (Dart >=3.2.0)**: Cross-platform framework.
- **dartssh2**: Pure Dart SSH2 protocol implementation.
- **xterm**: Robust terminal emulator widget.
- **flutter_pty**: Pseudo-terminal support for local shell processes.
- **provider**: Reactive state management via `ChangeNotifier`.
- **pointycastle** & **crypto**: Cryptographic primitives for key management.
- **uuid**: For unique resource identification (Profiles, Keys, Snippets).
- **shared_preferences**: Local data persistence for settings and configurations.

### Architecture

The project follows a modular Flutter architecture with clear separation of concerns:

- **`lib/models/`**: Defines the data structures for the application.
  - `ssh_profile.dart`: Connection settings for remote servers.
  - `ssh_key.dart`: Private and public SSH key representations.
  - `keyboard_shortcut.dart`: Custom keyboard shortcuts and key sequences.
  - `snippet.dart`: Reusable command fragments.
- **`lib/services/`**: Contains core logic and external system interactions.
  - `config_service.dart`: Handles loading/saving of all configurations via `shared_preferences`.
  - `network_discovery_service.dart`: Discovers IP addresses and services on the local network.
  - `ssh_key_generator.dart`: Logic for creating new SSH key pairs (RSA, ED25519).
- **`lib/providers/`**: Manages application state and notifies the UI of changes.
  - `ssh_provider.dart`: Core state for SSH client/server, terminal instances, and logs.
  - `settings_provider.dart`: App-wide settings (Themes, Accent Colors, Port defaults).
  - `snippet_provider.dart`: Manages the collection of user-defined command snippets.
- **`lib/screens/`**: High-level page structures (e.g., `HomeScreen`, `SplashScreen`, `SettingsScreen`).
- **`lib/widgets/`**: Reusable and modular UI components (e.g., `KeyManager`, `ProfileManager`, `LogViewer`).

## Building and Running

The project adheres to standard Flutter workflows:

- **Setup**: `flutter pub get`
- **Run (Debug Mode)**: `flutter run`
- **Build (Android)**: `flutter build apk`
- **Build (iOS)**: `flutter build ios`
- **Build (Windows)**: `flutter build windows`
- **Build (macOS/Linux)**: `flutter build macos` / `flutter build linux`
- **Test**: `flutter test`
- **Analyze**: `flutter analyze`

## Development Conventions

- **State Management**: Utilize `Provider` for all state-related tasks. Avoid direct state manipulation within widgets.
- **Persistence**: Always route data persistence through `ConfigService` to ensure consistency and central management of saved data.
- **Coding Style**: Strictly follow `package:flutter_lints/flutter.yaml` and local rules in `analysis_options.yaml`.
- **Strict Typing**: The project enforces `strict-casts: true` and `strict-raw-types: true`. Maintain explicit type declarations and safe casting.
- **Asynchronous Operations**: Ensure proper error handling (try-catch) and async safety for all network and PTY operations.
- **Logging**: Use `SSHProvider.addLog` to record significant events for user-facing logs.

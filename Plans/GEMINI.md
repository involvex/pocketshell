# GEMINI.md

## Project Overview
**ssh_app** is a Flutter-based application that provides both SSH client and server functionality. It allows users to connect to remote servers via SSH with a full terminal emulator and also host a local SSH server that provides access to the device's shell (CMD on Windows, SH on Unix-like systems).

### Main Technologies
- **Flutter (Dart >=3.2.0)**: Cross-platform framework.
- **dartssh2**: Pure Dart implementation of the SSH2 protocol.
- **xterm**: Terminal emulator widget for displaying SSH sessions.
- **flutter_pty**: Pseudo-terminal support for local shell processes.
- **provider**: State management via `ChangeNotifier`.
- **network_info_plus**: For discovering local network information (e.g., WiFi IP).

### Architecture
The project follows a standard Flutter architectural pattern with state management:
- **`lib/providers/`**: Contains `SSHProvider`, the central hub for managing SSH client and server states, terminal instances, and connection logs.
- **`lib/screens/`**: Contains the top-level UI structures (e.g., `HomeScreen` with navigation).
- **`lib/widgets/`**: Contains reusable UI components such as `SSHClientForm`, `SSHServerForm`, and `LogViewer`.

## Building and Running
The project follows standard Flutter development workflows:

- **Setup**: `flutter pub get`
- **Run (Debug Mode)**: `flutter run`
- **Build (Android)**: `flutter build apk`
- **Build (iOS)**: `flutter build ios`
- **Build (Windows)**: `flutter build windows`
- **Test**: `flutter test`
- **Analyze**: `flutter analyze`

## Development Conventions
- **State Management**: Always use `SSHProvider` via `Provider` or `Consumer` to access or modify SSH-related state.
- **Coding Style**: Adhere to `package:flutter_lints/flutter.yaml` and the custom rules in `analysis_options.yaml`.
- **Strict Typing**: The project enforces `strict-casts: true` and `strict-raw-types: true`. Ensure all types are explicitly declared and casts are handled safely.
- **Immutability**: Prefer `const` constructors and `final` fields where possible.
- **Logging**: Use `SSHProvider.addLog` to record important events, which are then viewable in the `LogViewer` tab.
- **Async Safety**: Use `unawaited` or handle `Future` results properly to avoid dangling promises, especially in terminal and socket listeners.

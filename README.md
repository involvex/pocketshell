# Pocketshell

A powerful and versatile Flutter-based SSH Client and Server application for Mobile and Desktop.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)

## Features

### 🚀 SSH Client

- Connect to any remote SSH server using passwords or private keys.
- **Full Terminal Emulator**: Built-in `xterm` terminal with full color and interactive support.
- **Session Persistence**: Keep your connections alive in the background.
- **Control Panel**: Quick access buttons for Ctrl, Alt, Arrow keys, and more.

### 🏠 SSH Server

- Host a local SSH server directly on your device.
- Provide secure remote access to your device's shell (CMD on Windows, SH/Bash on Unix-like systems).
- Configurable port and authentication.

### 🔑 Key Management

- Generate and manage SSH key pairs (RSA, ED25519, etc.).
- Securely store and use private keys for passwordless authentication.

### 📁 Profile Manager

- Save frequently used connection settings as profiles.
- Quick connect with a single tap.
- Organize your remote servers efficiently.

### ⌨️ Keyboard & Shortcuts

- **Custom Shortcut Bar**: Add your own frequently used commands or keys to a scrollable bar.
- **Global Hotkeys**: Use `Ctrl+N` (New Connection), `Ctrl+P` (Profiles), `Ctrl+K` (Keys), and `Ctrl+D` (Discovery).
- **Snippet Manager**: Store and inject command fragments into your active terminal sessions.

### 🔍 Network Discovery

- Scan your local network to find other devices and services.
- Quickly identify available SSH targets.

### 🎨 Highly Customizable

- **Theme Engine**: Support for Light, Dark, and System modes.
- **Accent Colors**: Choose your favorite color theme.
- **Terminal Styling**: Configurable font sizes and styles.

## Main Technologies

- **Flutter**: Cross-platform UI framework.
- **dartssh2**: Pure Dart implementation of the SSH2 protocol.
- **xterm**: Robust terminal emulator widget.
- **flutter_pty**: Pseudo-terminal support for local shell processes.
- **Provider**: Clean and reactive state management.
- **Network Info Plus**: For IP and network state detection.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.2.0)
- [Dart SDK](https://dart.dev/get-dart)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/involvex/pocketshell.git
   cd pocketshell
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the application:

   ```bash
   flutter run
   ```

### Building for Production

- **Android**: `flutter build apk`
- **iOS**: `flutter build ios`
- **Windows**: `flutter build windows`
- **macOS**: `flutter build macos`
- **Linux**: `flutter build linux`

## Project Structure

- `lib/models/`: Data structures for Profiles, Keys, Shortcuts, and Snippets.
- `lib/providers/`: State management for SSH, Settings, and Snippets.
- `lib/services/`: Core logic for configuration, key generation, and network discovery.
- `lib/screens/`: Top-level UI pages and tabs.
- `lib/widgets/`: Reusable UI components and modal dialogs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

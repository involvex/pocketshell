# PocketShell

A Flutter SSH client for mobile and desktop — connect to remote hosts, browse
files over SFTP, and chat with OpenCode agents on the same machine.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)

## Features

### SSH Client

- Connect with password or private-key auth (`dartssh2` + `xterm`).
- Multi-session tabs, reconnect, host-key trust, and configurable idle timeout.
- Shortcut bar (Ctrl/Alt/arrows), snippets, scrollback search, and selection copy.
- Background keepalive on Android via a foreground service.

### SFTP

- Browse remote files from an active session (sort, filter, mkdir/rename/delete).
- Upload/download with progress and cancel; Windows drive switching.
- Used by the Agents tab to pick an OpenCode project directory.

### Agents (OpenCode)

- Native HTTP UI for OpenCode V2 (`/api/*`) — no WebView.
- Sessions scoped by project directory; slash commands for `/agent`, `/model`,
  `/models`, and `/connect`.
- Config sheet plus remote import from the Windows host over SSH.

### Android extras

- Home-screen widgets for SSH quick-connect and latest agent session.
- Deep links: `sshapp://widget/ssh|agent?profileId=...`
- Share-to-clone: share a GitHub URL into the app to clone on a chosen profile.
- Share-to-host: share files/images into a connected session’s SFTP current directory.

### Customization & backup

- Themes (system / light / dark / hacker), accent colors, terminal fonts.
- Encrypted backup (password) or plain JSON export/import in Settings.

## Main Technologies

- **Flutter** — cross-platform UI
- **dartssh2** — SSH2 client
- **xterm** — terminal emulator
- **Provider** — state management
- **Dio** — OpenCode HTTP API
- **home_widget** — Android home-screen widgets (vendored)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `.github/flutter-version`)

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

- `lib/models/` — Profiles, keys, sessions, agent connection, snippets
- `lib/providers/` — SSH, Agents, Settings, Snippets, SFTP
- `lib/services/` — Config, OpenCode, SFTP, backup, widgets, lifecycle
- `lib/screens/` — Home, Agents, Settings, Splash
- `lib/widgets/` — Terminal, SFTP, agent chat, profiles/keys

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

# PocketShell — Feature Suggestions

A curated list of features, improvements, and enhancements that can be implemented in the PocketShell codebase.

---

## Security

### 1. Fix SSH Key Generation (Critical)
The current `SSHKeyGenerator` generates random bytes wrapped in PEM headers — these are **not valid cryptographic keys** and will fail real SSH authentication. Replace with proper key generation using `pointycastle` (RSA/ECDSA) or a dedicated Ed25519 package.

### 2. Migrate Private Keys to Secure Storage
SSH private keys are currently serialized to plaintext in `SharedPreferences`. Move them to `flutter_secure_storage` alongside passwords and passphrases. The `toJson()`/`fromJson()` methods already accept `includePassphrase`/`includePassword` flags, so the serialization layer is ready — only the storage backend needs changing.

### 3. Host Key Verification / Known Hosts
Connections use `SSHSocket.connect` without explicit host key verification. Implement a `known_hosts` file (stored in secure storage or the app's documents directory) that:
- Prompts the user on first connection to an unknown host
- Warns on host key mismatch (potential MITM attack)
- Allows trusting/ignoring specific hosts

### 4. SSH Agent Forwarding
Add support for SSH agent forwarding so that keys loaded on the local device can be used on the remote server without copying private keys to the remote host.

### 5. Keyboard Interactive Auth
Support keyboard-interactive authentication (e.g., 2FA prompts, Yubikey challenges) in addition to password and public-key auth.

---

## SSH Client Enhancements

### 6. Port Forwarding / Tunneling
Add local and remote port forwarding (`ssh -L` / `ssh -R`):
- UI to configure tunnels per profile or ad-hoc
- Persistent tunnel profiles saved alongside SSH profiles
- Visual indicator of active tunnels

### 7. Jump Host / ProxyJump Support
Allow configuring a chain of SSH hops to reach the target host through a bastion/jump server. This is common in enterprise environments and currently requires manual workarounds.

### 8. SSH Config File Import
Parse and import connections from `~/.ssh/config`:
- Auto-detect hosts, ports, users, keys, proxy jump settings
- Merge with existing profiles or create new ones
- Watch for config changes and offer re-import

### 9. Session Recording & Playback
Record terminal I/O for each session and allow playback:
- Save session transcripts with timestamps
- Export as text or replay in a read-only terminal
- Useful for auditing, tutorials, and debugging

### 10. Persistent Scrollback
Currently xterm's scrollback is ephemeral. Persist scrollback to disk so users can scroll back through previous sessions after reconnecting.

---

## SFTP Improvements

### 11. File Editing in SFTP
Add a text editor for remote files directly within the SFTP browser:
- Open files in a code-aware editor view
- Save changes back via SFTP write
- Syntax highlighting for common file types

### 12. File Comparison (Diff)
Compare two remote files or a local vs. remote file side by side with a diff viewer. Useful for config changes and code review.

### 13. Bookmark / Favorites
Allow bookmarking frequently accessed directories:
- Quick navigation sidebar
- Persistent across sessions
- Import from SSH config `RemoteForward` paths

### 14. Recursive Search
Add file content search (`grep -r`) across remote directories with results displayed in a navigable list.

### 15. Drag & Drop Upload
On desktop platforms, support dragging files from the OS file manager directly onto the SFTP browser to initiate uploads.

---

## Agent (OpenCode) Enhancements

### 16. Agent Session History Persistence
Currently agent messages are only in memory. Persist conversation history so sessions can be resumed after app restart or reconnection.

### 17. Multi-Agent Collaboration
Allow spawning multiple concurrent agent sessions that can share context or work on different tasks within the same project directory.

### 18. Agent Task Queue
Queue multiple prompts/tasks for sequential execution:
- Show progress of each queued task
- Allow reordering or cancelling queued tasks
- Persistent across app restarts

### 19. Agent Cost Tracking
Track token usage and estimated costs per session:
- Show token counts for input/output
- Display estimated cost based on provider pricing
- Budget alerts and session cost summaries

### 20. Agent Template Snippets
Pre-built agent prompt templates for common workflows:
- Code review, refactoring, bug fixing, documentation
- Custom templates created by the user
- Shareable template library

---

## Terminal & UX

### 21. Terminal Search
Add a search bar to the terminal view:
- Search forward/backward through scrollback
- Highlight matches in the terminal
- Regex support

### 22. Clipboard Integration on Mobile
On Android/iOS, add:
- Long-press to select text and copy
- A paste button in the toolbar or shortcut bar
- Auto-copy on selection (configurable)

### 23. Split-Pane Terminal
On tablet/desktop, allow viewing two terminal sessions side by side:
- Manual split (horizontal/vertical)
- Drag to resize
- Independent scrollback per pane

### 24. Command History Browser
A dedicated screen to browse, search, and re-execute previous commands:
- Filtered by profile or time range
- Pin frequently used commands
- Export as snippets

### 25. Custom Terminal Emulation Profiles
Beyond keyboard shortcuts, allow configuring:
- Tab width (2, 4, 8)
- Bell behavior (visual, audible, silent)
- Cursor style (block, underline, bar, blinking variants)
- Scrollback buffer size
- Encoding (UTF-8, ISO-8859-1, etc.)

### 26. Resizable Font with Pinch-to-Zoom
Allow pinch-to-zoom on the terminal view for quick font size adjustment, with the size snapping to the nearest configurable step.

---

## Settings & Configuration

### 27. Profile Groups / Folders
Organize SSH profiles into folders or tags:
- "Work", "Personal", "Servers", etc.
- Filter by group in the profile manager
- Quick-connect from a filtered list

### 28. Environment Variables per Profile
Allow setting environment variables that are sent to the remote shell on connect (e.g., `LANG=en_US.UTF-8`, `EDITOR=vim`).

### 29. Connection Profiles Sync
Sync profiles, keys, and settings across devices:
- End-to-end encrypted sync via a provider (e.g., iCloud, Google Drive, or self-hosted)
- Conflict resolution strategy
- Selective sync (profiles only, keys only, etc.)

### 30. Import/Export Profiles
Standalone import/export of SSH profiles (separate from the full backup):
- CSV or JSON format
- Share via QR code on mobile
- Password-protected export

### 31. Per-Profile Terminal Theme
Allow each SSH profile to have its own terminal color theme, font, and input settings rather than using global defaults.

---

## Logging & Observability

### 32. Enhanced Log Viewer
Improve the connection log viewer:
- Filter by log level (info, warning, error)
- Search by text or timestamp
- Export logs to file or share
- Color-coded log levels

### 33. Connection Analytics
Track and display connection statistics:
- Total connection time per profile
- Reconnection frequency
- Error rate and most common errors
- Uptime percentage

### 34. Debug Mode
A toggle in settings that enables verbose logging:
- Raw SSH protocol messages
- SFTP operation details
- Agent SSE event stream
- Write to a debug log file for sharing with support

---

## Platform-Specific

### 35. iOS Shortcuts / Siri Integration
Expose common actions as Siri Shortcuts:
- "Connect to [profile name]"
- "Run [snippet] on [host]"
- Siri suggestions based on usage patterns

### 36. iOS / macOS Home Screen Widgets
Extend Android home screen widgets to iOS (via WidgetKit) and macOS:
- Quick-connect widget for SSH profiles
- Agent quick-connect widget
- Configurable via widget settings

### 37. Chromebook / Linux Tablet Support
Optimize the UI for Chromebook and Linux tablet form factors:
- Large touch targets
- Stylus-friendly terminal input
- External keyboard detection

### 38. Windows Terminal Integration
On Windows, detect and integrate with Windows Terminal:
- Open a new Windows Terminal tab with the SSH connection
- Respect Windows Terminal color schemes and profiles

---

## Code Quality & Testing

### 39. Unit Tests for Providers
Create comprehensive unit tests for all providers:
- `SSHProvider` — connection, disconnect, reconnect, profile management
- `AgentProvider` — session lifecycle, message handling, permissions
- `SftpController` — file operations, navigation, selection
- Use `FakeConfigRepository` for test isolation

### 40. Widget Tests for Key Screens
Add widget tests for:
- `HomeScreen` — tab switching, app bar actions
- `SettingsScreen` — setting changes propagate correctly
- `ConnectionModal` — form validation, submit behavior
- `SftpBrowser` — navigation, file operations

### 41. Integration Tests
End-to-end tests that:
- Connect to a local SSH server (Docker-based)
- Verify terminal output/input round-trip
- Test SFTP file upload/download
- Exercise the agent chat flow

### 42. Replace Static ConfigService Calls with Repository Pattern
`SSHProvider` and other providers still call `ConfigService` statically. Migrate to dependency-injected `ConfigRepository` to improve testability and decouple from SharedPreferences.

### 43. Add Error Boundaries
Implement `FlutterError.onError` and `ErrorWidget.builder` to catch and display uncaught errors gracefully:
- Show a recovery dialog with error details
- Offer to restart the affected session
- Log errors to a file for debugging

---

## Miscellaneous

### 44. Vibration / Haptic Feedback
Add haptic feedback on mobile for:
- Connection established / disconnected
- Error occurrence
- Button presses in the shortcut bar
- Long-press context menus

### 45. Notification on Disconnect
Show a local notification when a backgrounded SSH session disconnects unexpectedly, with a "Reconnect" action button.

### 46. Quick Actions (Android App Shortcuts)
Add static and dynamic Android app shortcuts:
- Long-press app icon → recent profiles
- Dynamic shortcuts for last N connected profiles
- Pin a profile as a shortcut

### 47. Landscape Mode Optimization
Optimize the terminal view and SFTP browser for landscape mode:
- Wider terminal with more columns
- Side-by-side SFTP + terminal on tablets
- Auto-rotate terminal content

### 48. Localization / Internationalization
Add multi-language support:
- Extract all user-facing strings to ARB files
- Community-translated language packs
- RTL support for Arabic, Hebrew, etc.

### 49. Share Session as Text
Allow sharing the terminal output (scrollback) as a text file or directly to another app:
- Select a range of output
- Share via system share sheet
- Copy to clipboard

### 50. Gesture-Based Terminal Controls
Add customizable gesture controls:
- Swipe left/right to switch sessions
- Swipe down to scroll up in terminal
- Two-finger tap for context menu
- Three-finger tap for paste

---

*Generated from codebase analysis on 2026-08-27.*

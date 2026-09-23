# Suggestions — PocketShell (ssh_app)

Analysis date: 2026-09-22. Scope: `lib/` (SSH client via `dartssh2` + `xterm`, SFTP explorer, Agents/OpenCode tab, profiles/keys/snippets, backup, Android widgets + foreground service).

This file lists implementable features ordered by value. Each item notes the problem, proposal, and affected area. Security items first — they are quality gates, not nice-to-haves.

## How to use this list

- `Priority`: P0 = security/correctness gap, P1 = high user value, P2 = polish/scale.
- `Effort`: S (< 1 day), M (1–3 days), L (> 3 days or new permission/platform work).
- Start with Section 1 before expanding scope in Sections 2–8.

---

## 1. Security (P0 — do first)

### 1.1 Host-key verification with known_hosts (P0, M)
Problem: no `known_hosts` handling found in `lib/` (`SSHProvider` connects without pinning/checking host keys). Silent trust-on-every-connect exposes users to MITM.
Proposal:
- Store per-host key fingerprint on first connect, show full fingerprint + "Trust / Reject" dialog.
- Persist in `ConfigService` (e.g. `known_hosts` key) with host, port, key type, fingerprint, date added.
- On mismatch: hard-block connect with "Host key changed" warning, require explicit re-trust + log via `addLog()`.
- Show fingerprint in profile detail and connection modal.

### 1.2 App lock with biometrics + auto-lock (P0, M)
Problem: profiles, private keys (even via `SecureStorageService`), and agent passwords are one tap away once the app is open.
Proposal:
- Opt-in lock via `local_auth`: biometric or device PIN on cold start / resume after N minutes (configurable 1/5/15 min, in `SettingsProvider`).
- Lock overlays `HomeScreen`; `SSHProvider` sessions stay alive in background but terminal/SFTP content is hidden until unlock.
- Add "Lock now" toolbar action.

### 1.3 Encrypted backup with password (P0, M)
Problem: `BackupService.export()` writes profiles, private keys, and passphrases as plain JSON to a temp file + system share. Any app with share access can read secrets.
Proposal:
- Add `Encrypted (recommended)` export: AES-GCM via `cryptography` package, password-based key (Argon2id or PBKDF2, 600k iterations), wrong-password error without leaking metadata.
- Keep plain JSON only behind an explicit "I understand the risk" checkbox; strip secrets by default in plain mode.
- Validate `_maxBackupSizeBytes` on import before parsing; schema-version check already exists (`_backupVersion`) — bump to 2 for encrypted envelope.

### 1.4 SSH private-key passphrase enforcement + in-memory hygiene (P0, S)
Problem: keys can be stored/used without passphrases; decrypted key material lifetime is unbounded.
Proposal:
- Warn in `KeyManager` when importing a key without a passphrase; offer to set one.
- Zero out / drop decrypted key bytes after auth; never include private material in logs or `toJson()` (audit `SSHKey.toJson`, `SSHProfile.toJson`).
- Add "Require passphrase to use key" setting.

### 1.5 Keyboard-interactive / 2FA and SSH-certificate auth (P0, M)
Problem: password + static private key only. Many Windows hosts (primary target) and corporate servers require keyboard-interactive (2FA/TOTP) or certificates.
Proposal:
- Handle `dartssh2` keyboard-interactive prompts with a secure dialog (no echo, per-prompt labels).
- Support OpenSSH certificates (`*-cert.pub`) alongside raw keys; show expiry and principals in key detail.

### 1.6 Session idle timeout + auto-disconnect (P0, S)
Problem: backgrounded sessions live forever via `AppLifecycleService`/`ConnectionForegroundService`.
Proposal:
- Configurable idle timeout (e.g. 30 min default off): disconnect SSH + agent sessions, clear terminal scrollback optionally.
- Notify via `connectionLog` and Android notification before disconnect.

## 2. SSH connection core (P1)

### 2.1 SSH config import (`~/.ssh/config`) (P1, M)
Import host, hostname, user, port, identity file, jump host from desktop/server `~/.ssh/config` over existing SFTP channel or file picker. Map to `SSHProfile` fields; report skipped directives. Reduces manual profile setup, the top onboarding friction.

### 2.2 Jump host / bastion support (P1, M)
Add `jumpProfileId` to `SSHProfile`; `SSHProvider.connectClient()` dials bastion first, then tunnels (TCP forward via `dartssh2`) to target. UI: "Via jump host" picker in `ssh_client_form.dart`. Essential for Windows lab + cloud setups.

### 2.3 Local/remote port forwarding UI (P1, M)
Problem: no forwarding found in codebase. Users cannot reach RDP, DBs, or OpenCode behind NAT.
Proposal: per-profile forward rules (local port → remote host:port, reverse optional); active-forwards list with stop/start; conflict detection on local port bind. Persist in profile JSON.

### 2.4 Keepalive + auto-reconnect with backoff (P1, S)
Add heartbeat (SSH keepalive every 30 s, configurable), missed-heartbeat detection, and auto-reconnect (exponential backoff, max 5 tries) that re-attaches terminal without losing scrollback. Surface state in `AgentConnectionBar` / client header.

### 2.5 Multi-session tabs (P1, L)
`SSHProvider.sessions` + `activeSessionId` already model multi-session, but `HomeScreen` shows one terminal. Add a session tab strip (name, status dot, close button), per-session `SftpController`, and per-session log filter. This unlocks the existing architecture.

### 2.6 Connection health dashboard (P1, S)
Latency (ping over SSH channel), uptime, bytes in/out, reconnect count per session. Small header chip + details sheet. Cheap to build on existing session objects; high trust value.

### 2.7 Wake-on-LAN (P1, S)
Send magic packet from `NetworkDiscovery` screen to a saved MAC. Natural fit: discover → wake → connect flow for home Windows hosts.

## 3. Terminal + input (P1)

### 3.1 Search in scrollback + selection actions (P1, M)
`xterm` buffer search (Ctrl+F), match highlighting, jump-to-next/prev, copy-match. Plus "Copy all", "Save scrollback to file", "Clear". Addresses the most common terminal complaint.

### 3.2 Terminal recording and playback (P1, M)
Record session I/O to a local file (asciicast-compatible), replay in-app, share via `share_plus`. Useful for debugging Windows host issues and audit. Respect privacy: pause-recording toggle + indicator.

### 3.3 Split terminal/files workstation layout (P1, L)
`docs/features.md` explicitly marks split terminal|SFTP as out of scope. Revisit as an option on wide screens/desktop: resizable split with shared `SessionEntry`. Builds directly on `SftpController` (already session-scoped).

### 3.4 tmux-aware status + key passthrough (P1, S)
`SessionManager` already knows `tmux`. Add: tmux session picker on connect, detach shortcut, and fix prefix-key passthrough in `keyboard_shortcut_bar.dart` (currently easy to swallow Ctrl+B).

### 3.5 Ligature + font fallback polish (P2, S)
`TerminalStyleBuilder` centralizes styling — add font-fallback chain (e.g. JetBrains Mono → Noto), ligature toggle, line-height control. Low risk, visible quality win.

## 4. SFTP / file workflows (P1)

### 4.1 Background transfer queue with resume (P1, M)
Today transfers are modal and cancellable only. Add a persistent queue (per session): pause/resume, retry on reconnect, chunked resume via offset, system notification with progress. `SftpCancelToken` + `_transferBytes` plumbing already exists — extend it.

### 4.2 Permission + ownership editor (P1, S)
Numeric/symbolic chmod UI, recursive option, chown where permitted. Missing today; required for daily-driver server use (CHANGELOG 1.2.0 claims daily-driver UX).

### 4.3 Checksum verify after transfer (P1, S)
SHA-256 compare (remote `sha256sum` via SSH exec vs local hash) with pass/fail badge in `sftp_transfer_banner.dart`. Catches truncated uploads on flaky mobile networks.

### 4.4 Archive handling (P1, M)
Remote zip/tar create + extract (via SSH exec with fallback error message on Windows hosts without `tar`), download-as-zip for multi-select. Pairs with existing multi-select in `SftpController.selectedNames`.

### 4.5 Symlink + hidden-file support (P1, S)
Show symlink targets, toggle hidden files, resolve-then-open. Small model change in `RemoteFsEntry` + `SftpHelper` listing flags.

### 4.6 Edit remote file in place (P1, M)
Open text preview → edit → save back with atomic rename + backup (`.bak`) option. Reuses `sftp_text_preview.dart` with size cap already in place.

## 5. Profiles, keys, snippets organization (P1–P2)

### 5.1 Folders, tags, favorites, search (P1, M)
Flat profile list does not scale. Add folders/tags + favorites pin + search bar in `ProfileManager`. Persist `folderId`, `tags`, `isFavorite` in profile JSON (backward compatible via nullable fields).

### 5.2 Duplicate, QR share, deep-link connect (P1, S)
Duplicate-profile action; share a profile (host/port/username only, never secrets) via QR or `ssh://user@host:port` link; handle incoming links. Complements existing `sshapp://widget/ssh?profileId=` scheme.

### 5.3 `.ppk` (PuTTY) + OpenSSH import/export (P1, S)
Primary usage is Android → Windows hosts, where `.ppk` is common. Convert on import via `pointycastle`; export to OpenSSH/PEM. Show key type, bits, fingerprint in list.

### 5.4 Snippet variables and shell quoting (P1, S)
Snippets are static fragments today. Add `${1:placeholder}` prompts + safe shell quoting per target shell (PowerShell vs bash detection). Prevents injection bugs when injecting into active terminal.

### 5.5 Global hotkey + shortcut import/export (P2, S)
Backup already covers shortcuts; add per-shortcut export and a desktop global-hotkey to focus/show app. Small but sticky for desktop users.

## 6. Agents / OpenCode tab (P1)

### 6.1 File attachments + image input in chat (P1, M)
Attach local or SFTP-picked files to a prompt (`AgentPromptInput`); show upload progress; reference remote path in message. The SFTP directory picker already exists — wire it as the source.

### 6.2 Diff + apply preview for agent edits (P1, M)
Render file-change parts as unified diffs with accept/reject per hunk in `AgentMessagePartTile`. Currently messages group by role (`groupAgentMessages`) but edits lack review UX — risky for agent-driven workflows.

### 6.3 Voice input + TTS readout (P2, M)
Mic button in prompt input (on-device speech), optional TTS for agent replies. High value on Android mobile, the primary client.

### 6.4 Cost + model usage footer (P1, S)
Per-session token/cost tally from OpenCode metadata (`_loadMetadata` hook in `AgentProvider`), footer in `AgentChatPane` with per-model breakdown. Prevents billing surprises.

### 6.5 Offline prompt queue (P2, M)
Queue prompts while disconnected; auto-send on reconnect in order. Small state machine in `AgentProvider`; big reliability win on mobile networks.

### 6.6 Multi-connection compare (P2, L)
Run the same prompt against two profiles/models side by side. Leverages existing `_connections` list; needs a two-pane `AgentsTab` mode.

## 7. Platform + system integration (P2)

### 7.1 iOS widgets + App Intents (P2, M)
Android widgets exist (`WidgetProfileService`, `SshQuickConnectWidget`). Mirror minimal quick-connect on iOS and expose Siri/App Intents ("Connect to Homeserver").

### 7.2 Desktop system tray + minimize-to-tray (P2, S)
Tray icon with connect/disconnect, show/hide terminal, quit. Keeps long SSH sessions discoverable on Windows/Linux/macOS.

### 7.3 `ssh://` URL handling on all platforms (P2, S)
Register `ssh://` scheme (Android intent + Windows/macOS/Linux handlers) alongside existing `sshapp://`. Enables click-to-connect from docs/runbooks.

### 7.4 NFC / QR quick-connect for labs (P2, S)
Write a connection tag (non-secret fields) to NFC; tap to open connect sheet. Niche but cheap given 5.2.

### 7.5 Share sheet "Send to host" (P2, M)
Receive shared files/images from other apps → upload via active SFTP session. Uses existing transfer pipeline.

## 8. Reliability, a11y, and maintainability (P1)

### 8.1 Localization (i18n) (P1, M)
All strings are hardcoded English. Add `flutter_localizations` + `intl` ARB files (hang `l10n.yaml` already referenced in contribution docs), starting with the top user-requested locale. Required before any store featuring outside EN markets.

### 8.2 Accessibility pass (P1, M)
Minimum touch targets, screen-reader labels on terminal accessory bar, dynamic-type support, keyboard-only navigation for `HomeScreen` tabs. Pair with 3.1 search for motor-impaired users.

### 8.3 Crash reporting + opt-in diagnostics (P1, S)
Crash + ANR reporting (e.g. Sentry/Crashlytics) behind explicit opt-in in Settings; include redacted `connectionLog` (strip hostnames/secrets) on report. Today failures are invisible upstream.

### 8.4 Auto-backup + cloud sync opt-in (P2, M)
Scheduled encrypted auto-backup (ties to 1.3) with Google Drive / iCloud export target. Keep manual JSON flow as fallback.

### 8.5 Onboarding wizard + demo mode (P1, M)
First-run flow: create-or-import profile → test connect → tour of terminal/SFTP/Agents tabs. Demo mode with a fake session (no network) so store reviewers can explore. Reduces day-0 drop-off.

### 8.6 Test-coverage push for SSH/SFTP paths (P1, M)
`test/` covers models, sort utils, and some providers, but SSH connect/SFTP transfer paths lack hermetic tests. Add fakes for `dartssh2` client + `SftpFileSystem` (pattern already used: `FakeConfigRepository`) and golden tests for `AgentMessageBubble` grouping. Gate PRs on `flutter analyze` + `flutter test` (already the documented quality gate).

### 8.7 Performance: terminal frame + listing virtualization audit (P2, S)
Profile long-scrollback rendering and large SFTP directories (1k+ entries); virtualize `sftp_entry_list.dart`, cap syntax highlighting on huge previews (cap exists — verify it applies to all preview paths), and debounce filter input. Measure before/after with `flutter test --profile` + DevTools timeline.

---

## Suggested build order (if resourced as 3 milestones)

1. **Trust release (1.1, 1.3, 1.4, 2.4):** host-key trust, encrypted backup, key hygiene, keepalive/reconnect. Ships as 1.3.0.
2. **Daily-driver release (2.5, 3.1, 4.1–4.3, 5.1):** multi-session tabs, scrollback search, transfer queue + checksums, profile folders/search. Ships as 1.4.0.
3. **Agent-power release (6.1, 6.2, 6.4, 8.1, 8.5):** attachments, diff review, cost footer, first locale, onboarding wizard. Ships as 1.5.0.

## Out of scope (deliberately not suggested)

- Reintroducing a local SSH Server tab (removed as non-functional stub — per project guidance, do not re-add without a real host implementation).
- Web terminal target (`flutter_pty` has no web support).
- Side-by-side Agents split on wide screens (project standard is master-detail navigation on all sizes).

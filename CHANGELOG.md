# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Android share-to-host: shared files/images upload through the SFTP transfer queue (session picker when multiple connections; Connect & upload when none).


## [1.4.1] - 2026-11-26

### Changed

- v1.4.1
### Added

- SSH config import pulls unencrypted `IdentityFile` PEMs over SFTP and attaches them to profiles that do not already have a key (encrypted/missing/already-keyed paths stay as hints).
- Hold ← → ↑ ↓ on the shortcut bar to auto-repeat cursor movement (400ms delay, then ~45ms interval).


## [1.4.0] - 2026-11-22

### Changed

- v1.4.0
### Added

- Probe remote Windows drive letters (`C:`–`Z:`) over SFTP from Android (and any client OS).
- Foreground SSH auto-reconnect with exponential backoff when the link drops; clean remote `exit` stays disconnected.
- Atomic SFTP text saves via temp + rename, with optional `.bak` of the previous file.
- OpenCode config sheet writes host `opencode.json` over SFTP (HTTP PATCH remains for `{"shell": ...}` only).
- PowerShell snippet pack for Windows OpenSSH hosts (migrated into existing installs).

### Changed

- `wt` / `psmux` session managers no longer inject a non-PTY startup command and are hidden from new profile picks.
- Key Manager warns and offers “Set now” after generate / PPK import when the key has no passphrase.

## [1.3.2] - 2026-11-22

### Changed

- v1.3.2
### Added

- Jump host (ProxyJump) support via a saved bastion profile, including config import.
- Named local port forwards per profile (RDP preset) with start/stop while connected.
- PuTTY `.ppk` v2/v3 key import (ssh-ed25519 / ssh-rsa) into OpenSSH PEM keys.
- Wake-on-LAN from Network Discovery using a profile MAC or a manual address.
- Opt-in app lock (biometric / device credential) with auto-lock delay and Lock now.


## [1.3.1] - 2026-11-16

### Changed

- v1.3.1
### Added

- SSH keyboard-interactive authentication (2FA/TOTP prompts) with secure dialog.
- Opt-in OpenCode agent tunnel over SSH local forward to remote `127.0.0.1:agentPort`.
- Import OpenSSH `~/.ssh/config` from the connected host into profiles.
- Profile search, favorites pin, and duplicate in the profile manager.

## [1.3.0] - 2026-11-15

### Added

- SFTP transfer queue with cancel-current / clear-queue and download resume.
- SFTP permissions (chmod) sheet with recursive option and soft-fail on unsupported hosts.
- Optional SHA-256 verify after single-file SFTP transfers (incl. Windows Get-FileHash fallback).
- Agent chat file attachments (local + remote SFTP) via OpenCode `files[]`.
- Agent diff preview with session revert (stage/commit) for file edits.
- Agent session token/cost usage footer when the server reports usage.

## [1.2.2] - 2026-11-15

### Fixed

- Terminal search jump-to-match no longer breaks text selection (anchor ownership).
- Selection handles stay aligned while scrolling the terminal scrollback.
- Agents chat no longer shows a duplicate prompt input bar.

### Changed

- Copy from the terminal selection toolbar clears the selection and shows a character count.
- Mouse/tap events to the remote session are paused while a selection is active.
- README and feature docs updated for PocketShell / Agents / SFTP; removed unused `flutter_pty` dependency.

## [1.2.1] - 2026-10-13

### Changed

- Terminal selection handles with copy toolbar; Android share-to-clone with profile picker
## [1.2.0] - 2026-07-20

### Changed

- SSH auth, session durability, and SFTP daily-driver UX
## [1.1.0] - 2026-07-20

### Changed

- SFTP explorer foundations: sort, filter, file ops, progress, capped preview
## [1.0.5] - 2026-07-16

### Changed

- v1.0.5
## [1.0.4] - 2026-07-13

### Fixed

- Remove empty assets directory declaration causing CI analyze failure




## [1.0.3] - 2026-07-13

### Changed

- v1.0.3
## [1.0.2] - 2026-07-02

### Changed

- v1.0.2
## [1.0.1] - 2026-07-01

### Changed

- v1.0.1
## [1.0.0] - 2026-06-28

### Added

- PocketShell display branding and runtime version in Settings (via `package_info_plus`).
- SSH client and server with xterm terminal, profiles, keys, and snippets.
- Agents tab with OpenCode integration, SSE reconnect, and grouped chat UI.
- Android foreground service for stable background SSH/agent connections.
- Home screen widgets and deep links (`sshapp://widget/ssh|agent`).
- Backup export/import, network discovery, SFTP browser, and theme options.

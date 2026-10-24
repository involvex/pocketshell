# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Terminal search jump-to-match no longer breaks text selection (anchor ownership).
- Selection handles stay aligned while scrolling the terminal scrollback.

### Changed

- Copy from the terminal selection toolbar clears the selection and shows a character count.
- Mouse/tap events to the remote session are paused while a selection is active.



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

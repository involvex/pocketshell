# Features

## SSH client

Connect to remote hosts with password or private-key auth. The built-in xterm
terminal supports colors, scrollback, and a shortcut bar for Ctrl, Alt, arrows,
and custom snippets.

### SFTP (Client + Agents)

From an active Client session, open the SFTP browser (modal) to list drives,
navigate folders, and upload/download single files. The Agents tab reuses SFTP
to pick an OpenCode project directory on the same host.

Explorer foundations include typed listings, sort/filter, mkdir/rename/delete,
transfer progress/cancel, overwrite confirmation, and capped text/image
preview. Spec:
[2026-07-20-sftp-explorer-foundations.md](superpowers/plans/2026-07-20-sftp-explorer-foundations.md).
Split terminal|files “workstation” layout remains out of scope.

## Agents (OpenCode)

The **Agents** tab talks to an OpenCode HTTP API on the connected host.
Sessions are scoped by project directory; slash commands handle model and
provider configuration (`/model`, `/models`, `/connect`, `/agent`).

## Android extras

- **Foreground service** keeps SSH and agent sessions alive in the background
- **Home-screen widgets** quick-connect SSH or resume the latest agent session
- Deep links: `sshapp://widget/ssh|agent?profileId=...`

## Customization

| Area | Options |
|------|---------|
| Theme | system, light, dark, hacker |
| Accent | blue, green, purple, orange, red |
| Terminal | font family, size, weight, style via `TerminalStyleBuilder` |
| Shortcuts | configurable keyboard bar and global hotkeys |

## Backup

Export and import profiles, keys, snippets, and settings as JSON through the
backup service in Settings.

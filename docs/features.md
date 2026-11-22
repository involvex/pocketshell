# Features

## SSH client

Connect to remote hosts with password, private-key, or keyboard-interactive
(2FA/TOTP) auth. Profiles can use a jump host (ProxyJump), named local port
forwards (including an RDP preset), and Wake-on-LAN via a saved MAC. The
built-in xterm terminal supports colors, scrollback, and a shortcut bar for
Ctrl, Alt, arrows, and custom snippets. Profiles can be searched, pinned as
favorites, duplicated, or imported from the host’s `~/.ssh/config` over an
active SFTP session (including ProxyJump and LocalForward when resolvable).
PuTTY `.ppk` keys can be imported in Key Manager. Opt-in app lock covers the
UI with biometrics / device PIN while sessions stay connected.

### SFTP (Client + Agents)

From an active Client session, open the SFTP browser (modal) to list drives,
navigate folders, and upload/download single files. The Agents tab reuses SFTP
to pick an OpenCode project directory on the same host.

Explorer foundations include typed listings, sort/filter, mkdir/rename/delete,
transfer progress/cancel, overwrite confirmation, and capped text/image
preview. Spec:
[2026-07-20-sftp-explorer-foundations.md](https://github.com/involvex/pocketshell/blob/main/docs/superpowers/plans/2026-07-20-sftp-explorer-foundations.md).
Split terminal|files “workstation” layout remains out of scope.

## Agents (OpenCode)

The **Agents** tab talks to an OpenCode HTTP API on the connected host.
Sessions are scoped by project directory; slash commands handle model and
provider configuration (`/model`, `/models`, `/connect`, `/agent`).

When OpenCode listens only on the Windows host loopback, enable **Tunnel agent
over SSH** on the profile: the app opens an SSH local forward to
`127.0.0.1:agentPort` and connects Agents through that tunnel.

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

Export and import profiles, keys, snippets, and settings through Settings.
Encrypted backup (password-protected AES-GCM envelope, schema v2) is the
recommended path; plain JSON remains available behind an explicit risk
acknowledgement.

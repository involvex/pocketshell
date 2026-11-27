# Privacy Policy — PocketShell

PocketShell is an SSH/SFTP client and optional OpenCode agent UI. It does **not** include advertising, crash reporting, or analytics SDKs.

Last updated: 2026-11-26.

## Data stored on your device

- SSH profiles (host, port, username, agent settings) in app preferences.
- Passwords, agent passwords, private keys, key passphrases, and optional AI API keys in Android Keystore-backed encrypted storage (`flutter_secure_storage`).
- Android Auto Backup is off (`allowBackup=false`); backup/data-extraction rules also exclude SharedPreferences and `FlutterSecureStorage`.
- Connection / agent / SFTP error text shown in the Logs tab is redacted for Basic/Bearer tokens, password fields, and PEM blobs before display.
- Known-host fingerprints for SSH host-key verification.
- Command snippets, UI settings, and an in-app connection log (capped, not uploaded).
- Opt-in app lock uses the device biometric/credential APIs. Sessions stay connected while the UI is locked.

Android Auto Backup of app preferences is **disabled**. Use Settings → encrypted backup if you want a portable copy of profiles and keys.

## Network

PocketShell only opens network connections that you start:

- SSH/SFTP to hosts in your profiles.
- Optional OpenCode HTTP(S) to a host and port you configure (often your own Windows machine). HTTP without an SSH tunnel sends the agent password in cleartext on that network; prefer HTTPS or “Tunnel agent over SSH”.
- Optional terminal command generation (the wand) to `opencode.ai` and/or `api.kilo.ai` **only when you enter an API key and tap generate**. Keys stay on the device. F-Droid builds that include the wand declare **NonFreeNet**. Some builds (e.g. IzzyOnDroid) compile the wand out with `--dart-define=CLOUD_AI=false`.
- Optional Google Fonts CDN is **not** used; terminal fonts are bundled.

Home-screen widgets store profile id, name, host, and ports only (no passwords). Share intents can copy a Git URL or files you send into the app for clone/upload on a host you choose.

## What we do not collect

The authors of PocketShell do not operate a backend that receives your profiles, keys, terminal contents, or usage statistics.

## Source

https://github.com/involvex/pocketshell

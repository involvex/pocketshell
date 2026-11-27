- [x] The app complies with the inclusion criteria
- [x] The app is not already listed in the repo or issue tracker
- [x] The app has not already been requested
- [x] The upstream app source code repo contains the app metadata (summary/description/images/changelog/etc) in a Fastlane or Triple-T folder structure
- [x] The original app author has been notified, and does not oppose the inclusion

#### APPLICATION ID: com.involvex.ssh_app_flutter

```yaml
Categories:
  - Remote Access
  - Connectivity
  - Internet
  - Security
License: MIT
AuthorName: involvex
WebSite: https://github.com/involvex/pocketshell
SourceCode: https://github.com/involvex/pocketshell
IssueTracker: https://github.com/involvex/pocketshell/issues
Changelog: https://github.com/involvex/pocketshell/blob/HEAD/CHANGELOG.md
AutoName: PocketShell
RepoType: git
Repo: https://github.com/involvex/pocketshell.git
AntiFeatures:
  NonFreeNet:
    en-US: Optional terminal AI wand calls opencode.ai and api.kilo.ai only when the user pastes an API key and taps generate.
```

Full draft recipe (ABI split, Flutter 3.47.9 srclib, NDK 28.2.13676358, heap/daemon patch):
https://github.com/involvex/pocketshell/blob/HEAD/docs/fdroid.yml

Please build tag **v1.4.2** (`1.4.2+16` → versionCodes 161 / 162 / 163).
Do not use **v1.4.1** (that tag has no Fastlane).

Why do you want this app added to F-Droid:

Upstream author requesting inclusion. Fastlane metadata lives at
`fastlane/metadata/android/en-US/`. Privacy policy is `PRIVACY.md`. Optional
terminal AI wand is **NonFreeNet** (`opencode.ai` / `api.kilo.ai` only when
the user pastes an API key and taps generate).

Summary:

SSH, SFTP, and OpenCode agents in your pocket

Description:

PocketShell is an SSH/SFTP client with an OpenCode Agents tab. Connect to
hosts you configure, browse files over SFTP, and talk to an OpenCode server
on that same machine without a WebView.

- Password, public-key, and keyboard-interactive (2FA) authentication
- Host-key trust on first connect; changed keys are blocked
- Multi-session terminals, snippets, jump hosts, and local port forwards
- Optional biometric app lock; credentials stay in Android Keystore
- No ads, analytics, or crash reporters

The Agents tab talks only to the OpenCode URL on the SSH profile. The
optional terminal wand calls `opencode.ai` / `api.kilo.ai` only if you paste
your own API key and tap generate (NonFreeNet).

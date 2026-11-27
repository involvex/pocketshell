# F-Droid RFP checklist

Open an issue at https://gitlab.com/fdroid/rfp/-/issues against tag
**v1.4.2** (newer than v1.4.1; that older tag has no Fastlane).

## File the RFP

GitHub already has Fastlane on **v1.4.2**. Paste
[docs/fdroid-rfp-issue.md](fdroid-rfp-issue.md) into a new
https://gitlab.com/fdroid/rfp/-/issues issue.

Local listing check:

```powershell
./scripts/fdroid-preflight.ps1
```

Phone screenshots are already in
`fastlane/metadata/android/en-US/images/phoneScreenshots/`. Re-render with:

```powershell
./scripts/render-fdroid-screenshots.ps1
```

Or capture live sessions from a phone:

```powershell
./scripts/capture-fdroid-screenshots.ps1
```

## App

- Application ID: `com.involvex.ssh_app_flutter`
- Name: PocketShell
- License: MIT
- Source: https://github.com/involvex/pocketshell
- Flutter pin: see `.github/flutter-version` (currently 3.47.9)
- Vendored plugin: `packages/home_widget` (BSD-3, AGP 9 patch)
- Bundled fonts: OFL under `assets/fonts/` (no Google Fonts CDN)

## Anti-Features

- **NonFreeNet**: optional terminal AI wand calls `https://opencode.ai/zen/v1`
  and `https://api.kilo.ai/api/gateway` with a user-supplied API key.
  Self-hosted OpenCode (Agents tab) talks only to the host in the SSH profile.

## Metadata in this repo

- `fastlane/metadata/android/en-US/` (title, descriptions, changelog, icon, feature graphic). `scripts/release.ps1` writes changelog files for the universal build number and for F-Droid ABI codes (`*10+1/2/3`).
- `PRIVACY.md` (also bundled in the APK)
- Draft recipe: `docs/fdroid.yml` (srclib Flutter 3.47.9, NDK 28.2.13676358, ABI split, `pub get --enforce-lockfile`, Gradle heap patched for the buildserver)

## Screenshots

4–6 PNGs are in `fastlane/metadata/android/en-US/images/phoneScreenshots/`
(max 2:1 height:width). In-tree widget renders (replace with device shots
if you want a live session):

1. `01-client.png` — Connected Client session (Windows PowerShell demo)
2. `02-connect.png` — SSH connection form
3. `03-agents.png` — Agents connect
4. `04-settings.png` — Settings / security
5. `05-privacy.png` — Privacy policy
6. `06-host-key.png` — Unknown host-key dialog

## GitHub APK signing

F-Droid rebuilds and signs with its own key. GitHub Releases stay
debug-signed until these repository secrets exist:

- `ANDROID_KEYSTORE_BASE64` — `base64 -w0 upload-keystore.jks`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Locally: copy `android/keystore.properties.example` to
`android/keystore.properties` (gitignored) and put `upload-keystore.jks`
next to `android/app/build.gradle.kts`. Keep the upload keystore off the repo.

IzzyOnDroid is out of scope while the optional cloud LLM wand remains
(their AI policy rejects commercial-gateway frontends).

---

## Paste into the GitLab RFP issue

Title: `com.involvex.ssh_app_flutter — PocketShell`

Body: copy [docs/fdroid-rfp-issue.md](fdroid-rfp-issue.md).

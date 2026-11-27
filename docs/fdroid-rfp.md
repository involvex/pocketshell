# F-Droid RFP checklist

RFP filed: https://gitlab.com/fdroid/rfp/-/work_items/4880
(`com.involvex.ssh_app_flutter — PocketShell`, tag **v1.4.2**).

fdroiddata MR: https://gitlab.com/fdroid/fdroiddata/-/merge_requests/59275
(fork CI green: `fdroid build`, `check apk`, `rewritemeta`, lint — do not
open a duplicate RFP). Waiting on maintainer review. Recipe draft:
[docs/fdroid.yml](fdroid.yml) (matches the MR; prebuild enables R8 minify,
strips foojay-resolver, excludes `com.google.android.play`).

Local listing check:

```powershell
./scripts/fdroid-preflight.ps1
```

Packager reproduce notes: [docs/fdroid-building.md](fdroid-building.md).
IzzyOnDroid path (separate APK with cloud AI compiled out): [docs/izzyondroid.md](izzyondroid.md).

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
  Cold start and splash do not open those hosts; empty API key fails before Dio.
  Covered by `test/services/ai_gateway_service_test.dart`.
  Self-hosted OpenCode (Agents tab) talks only to the host in the SSH profile.

## Metadata in this repo

- `fastlane/metadata/android/en-US/` (title, descriptions, changelog, icon, feature graphic). `scripts/release.ps1` writes changelog files for the universal build number and for F-Droid ABI codes (`*10+1/2/3`).
- `PRIVACY.md` (also bundled in the APK)
- Draft recipe: `docs/fdroid.yml` (srclib Flutter 3.47.9, NDK 28.2.13676358, ABI split, `pub get --enforce-lockfile`, Gradle heap patched for the buildserver, R8 minify + Play Core exclude for the F-Droid APK scanner, `distributionSha256Sum` for the v1.4.2 Gradle wrapper)
- Upstream `main` also enables R8 + `android/app/proguard-rules.pro` and sets `distributionSha256Sum` on the Gradle wrapper (issuebot `insecure-gradlew`) for the next tag
- issuebot on RFP #4880: Fastlane OK, Flutter/Gradle/license labels OK; only actionable flag was `insecure-gradlew` (addressed above)

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

F-Droid rebuilds and signs with its own key. IzzyOnDroid / sideload need a
developer-signed APK — full steps: [android-signing.md](android-signing.md).

IzzyOnDroid: ship `*-izzy.apk` with `--dart-define=CLOUD_AI=false` (see
[izzyondroid.md](izzyondroid.md)). F-Droid keeps NonFreeNet + cloud AI on.

---

## Paste into the GitLab RFP issue

Title: `com.involvex.ssh_app_flutter — PocketShell`

Body: copy [docs/fdroid-rfp-issue.md](fdroid-rfp-issue.md).

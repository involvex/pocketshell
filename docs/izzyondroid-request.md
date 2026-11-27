# IzzyOnDroid app request (draft — do not file until signed `-izzy` APK exists)

Open at: https://codeberg.org/IzzyOnDroid/repodata/issues/new

## Checklist

- [x] I am the developer of the app.
- [x] The app complies with the App Inclusion Policy.
- [x] The app is not already listed in the repo or issue tracker.
- [x] Fastlane metadata is in the upstream repo.

## App

- **Name:** PocketShell
- **Application ID:** `com.involvex.ssh_app_flutter`
- **License:** MIT
- **Source:** https://github.com/involvex/pocketshell
- **Category:** Connectivity / Remote Access

## What it does

FOSS SSH/SFTP client for Android with multi-session terminals, host-key
trust, jump hosts, local port forwards, and biometric app lock. (This Izzy
APK omits the optional OpenCode Agents tab and cloud AI wand.)

## Anti-Features

None for the Izzy APK. Compiled out with
`--dart-define=CLOUD_AI=false --dart-define=AGENTS=false`:

- optional cloud LLM wand (`opencode.ai` / `api.kilo.ai`)
- OpenCode Agents tab (self-hosted LLM UI)

(F-Droid ships a separate build with NonFreeNet + Agents.)

## APK

- Release asset: `PocketShell-vX.Y.Z-izzy.apk` on the GitHub Release for tag
  `vX.Y.Z` (release-signed; not the debug-signed default artifact).
- Build: `flutter build apk --release --dart-define=CLOUD_AI=false --dart-define=AGENTS=false`

## Notes

- `android:allowBackup=false`; SharedPreferences / FlutterSecureStorage
  excluded from backup rules.
- No ads, analytics, or crash reporters.
- Fastlane: `fastlane/metadata/android/en-US/`
- Privacy: `PRIVACY.md`
- F-Droid RFP / recipe (different APK): https://gitlab.com/fdroid/rfp/-/work_items/4880

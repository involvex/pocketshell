# Android release signing (GitHub / IzzyOnDroid)

F-Droid rebuilds and signs with its own key. **IzzyOnDroid and sideload users
need a developer-signed release APK.**

## Status

- Tag **v1.4.2** GitHub Release has **no APK assets** (release workflow failed on a
  greedy aapt `name=` parse; fixed on `main` in
  `.github/scripts/verify-split-apk-versioncode.sh`). The unreleased workflow now
  uploads named APKs as Actions artifacts **before** ABI verify so a similar miss
  still leaves downloadable builds. F-Droid is unaffected — it rebuilds from the tag.
- Repo Actions secrets currently have **no** `ANDROID_KEYSTORE_*` entries, so even
  a green release would upload **debug-signed** APKs until secrets are set.
- Izzy needs a **later tag** that includes `CLOUD_AI=false` release artifacts plus
  release signing (not v1.4.2).

## Quick setup (recommended)

```powershell
# Creates android/app/upload-keystore.jks + android/keystore.properties
./scripts/setup-android-keystore.ps1

# Same, then pipes secrets into `gh secret set` via stdin (not argv)
./scripts/setup-android-keystore.ps1 -UploadSecrets
```

## Manual GitHub Actions secrets

Set these on https://github.com/involvex/pocketshell/settings/secrets/actions :

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` (Linux/macOS) or PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes('upload-keystore.jks'))` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (example: `upload`) |
| `ANDROID_KEY_PASSWORD` | key password |

`.github/scripts/configure-android-signing.sh` writes `android/keystore.properties`
and `android/app/upload-keystore.jks` on the runner when `ANDROID_KEYSTORE_BASE64`
is set. Otherwise GitHub Release APKs stay **debug-signed** (F-Droid unaffected).

## Local release signing

```powershell
./scripts/setup-android-keystore.ps1   # or copy keystore.properties.example
flutter build apk --release
# Izzy variant:
./scripts/build-izzy-apk.ps1
```

## Izzy artifact

After secrets are set **and** the listing/`CLOUD_AI` work is on a tagged release:

- `PocketShell-vX.Y.Z.apk` — cloud AI on
- `PocketShell-vX.Y.Z-izzy.apk` — `--dart-define=CLOUD_AI=false`

Point the Codeberg Izzy request at the `-izzy` asset only
([docs/izzyondroid-request.md](izzyondroid-request.md)).

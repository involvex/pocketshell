# Building PocketShell the F-Droid way

Packagers: prefer the recipe already opened as
[fdroiddata !59275](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/59275).
The draft lives at [docs/fdroid.yml](fdroid.yml). First listing tag is **v1.4.2**
(versionCodes 161 / 162 / 163).

## Reproduce locally (close to buildserver)

```bash
# Pin matches .github/flutter-version
flutter --version   # expect 3.47.9
git checkout v1.4.2

# Optional: apply the same prebuild sed steps as docs/fdroid.yml
# (foojay strip, R8 minify, Play Core exclude, Gradle distributionSha256Sum,
# heap/daemon patch), then:

flutter config --no-analytics
flutter pub get --enforce-lockfile
export ANDROID_NDK_HOME=…   # NDK 28.2.13676358
flutter build apk --release --split-per-abi \
  --target-platform=android-arm64
```

## Local gates before tagging

```powershell
./scripts/fdroid-preflight.ps1
```

When a release APK is present under `build/app/outputs/flutter-apk/`, preflight
scans dex for `com.google.android.play` / GMS / Firebase strings.

## Privacy / backup

- `android:allowBackup="false"`
- `backup_rules.xml` / `data_extraction_rules.xml` exclude all SharedPreferences
  plus `FlutterSecureStorage`
- Optional AI wand is **NonFreeNet**; cold start does not contact those hosts

## Do not build from `main` for the first listing

`main` may be ahead (Dependabot AGP/Gradle). Stay on **v1.4.2** until a later
update MR.

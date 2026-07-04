# Releases

PocketShell uses [Semantic Versioning](https://semver.org/) and
[Keep a Changelog](https://keepachangelog.com/).

## Creating a release locally

```powershell
./scripts/release.ps1
./scripts/release.ps1 -Message "Fix connection timeout"
./scripts/release.ps1 -DryRun
```

The script bumps `pubspec.yaml`, prepends `CHANGELOG.md`, runs analyze/test,
commits `chore(release): vX.Y.Z`, tags `vX.Y.Z`, and pushes.

## CI release (tag push)

Pushing a `v*` tag triggers the **Release** workflow:

1. Extracts the matching section from `CHANGELOG.md`
2. Builds a release APK (`flutter build apk --release`)
3. Publishes a [GitHub Release](https://github.com/involvex/pocketshell/releases)
   with the APK attached as `PocketShell-vX.Y.Z.apk`

## Download APK

Grab the latest APK from the
[Releases](https://github.com/involvex/pocketshell/releases) page after a tag
is pushed.

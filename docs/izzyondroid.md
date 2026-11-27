# IzzyOnDroid listing notes

IzzyOnDroid’s [AI policy](https://izzyondroid.org/docs/general/AppInclusionPolicy/)
rejects apps that act as front-ends for LLMs / big AI platforms. PocketShell’s
optional terminal wand **and** the OpenCode Agents tab fall under that risk.

## Build for Izzy (cloud AI + Agents UI off)

```powershell
./scripts/build-izzy-apk.ps1
```

That runs
`flutter build apk --release --dart-define=CLOUD_AI=false --dart-define=AGENTS=false`,
copies `PocketShell-izzy-local.apk`, and fails if dex still contains
`opencode.ai` / `api.kilo.ai`. The wand and Agents tab are hidden.

F-Droid continues to ship the default build (`CLOUD_AI=true`, `AGENTS=true`)
with **NonFreeNet**.

Tagged GitHub Releases (`.github/workflows/release.yml`) attach:

- `PocketShell-vX.Y.Z.apk` — cloud AI + Agents on
- `PocketShell-vX.Y.Z-izzy.apk` — `CLOUD_AI=false` + `AGENTS=false`

## Prerequisites before filing

1. Land `kCloudAiEnabled` / `--dart-define=CLOUD_AI=false` on a tagged release
2. Attach a **release-signed** `*-izzy.apk` (Izzy rejects debug keys;
   `./scripts/setup-android-keystore.ps1 -UploadSecrets`, then tag —
   see [android-signing.md](android-signing.md)). **v1.4.2 has no GitHub APKs.**
3. Fastlane metadata already present (same as F-Droid)
4. Open a request at https://codeberg.org/IzzyOnDroid/repodata/issues with the
   template; point at the `-izzy` APK (no NonFreeNet / no LLM gateway UI)

Do **not** file the default NonFreeNet APK at Izzy — their AI policy rejects
LLM gateway front-ends.

## Status

Code path ready locally (dex scan clean). Still deferred until: commit lands,
next tag ships `*-izzy.apk`, and `ANDROID_KEYSTORE_*` signs it. Draft request:
[docs/izzyondroid-request.md](izzyondroid-request.md). F-Droid path is active:
RFP #4880 / fdroiddata !59275.

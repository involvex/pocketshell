# Patched home_widget 0.9.3

Vendored path dependency with one Android Gradle change so Flutter's built-in Kotlin
detector does not flag `apply plugin: 'kotlin-android'` in `android/build.gradle`.

Upstream fix: use `plugins.apply('org.jetbrains.kotlin.android')` inside the AGP 9
conditional block (same pattern as `share_plus`).

Also dropped `pub/screenshots` binaries, the unused nested Gradle 8.1
wrapper under `android/gradle/`, and `resolution: workspace` so F-Droid
issuebot does not scan unused GIF/PNG/wrapper files and the path dep
does not expect a pub workspace. The F-Droid recipe still `rm`s
`android/gradle` if it reappears.

Remove this package when pub.dev `home_widget` ships the AGP 9 fix.

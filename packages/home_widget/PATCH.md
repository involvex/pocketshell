# Patched home_widget 0.9.3

Vendored path dependency with one Android Gradle change so Flutter's built-in Kotlin
detector does not flag `apply plugin: 'kotlin-android'` in `android/build.gradle`.

Upstream fix: use `plugins.apply('org.jetbrains.kotlin.android')` inside the AGP 9
conditional block (same pattern as `share_plus`).

Remove this package when pub.dev `home_widget` ships the fix.

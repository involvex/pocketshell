# Flutter embedding references Play Core for unused deferred components.
# The com.google.android.play group is excluded in build.gradle.kts; keep R8 quiet.
-dontwarn com.google.android.play.**

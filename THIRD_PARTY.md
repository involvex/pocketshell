# Third-party licenses

PocketShell itself is MIT (`LICENSE`). F-Droid and the in-app
**Open-source licenses** screen also need these bundled works:

| Component | License | Location |
| --- | --- | --- |
| Terminal fonts (JetBrains Mono, Fira Code, Space Mono, Source Code Pro) | SIL OFL 1.1 | `assets/fonts/OFL.txt` |
| Vendored `home_widget` (AGP 9 patch) | BSD-3-Clause | `packages/home_widget/LICENSE` |
| `material_ui` (Flutter Material library) | BSD-3-Clause | pub.dev `material_ui` |
| `opencode_api` | MIT | pub.dev `opencode_api` |
| `dartssh2` | MIT | pub.dev `dartssh2` |
| `xterm` | MIT | pub.dev `xterm` |
| `dio` | MIT | pub.dev `dio` |
| `flutter_secure_storage` | BSD-3-Clause | pub.dev `flutter_secure_storage` |
| `local_auth` | BSD-3-Clause | pub.dev `local_auth` |
| `pointycastle` / `cryptography` / `crypto` | BSD-style / Apache-2.0 / BSD | pub.dev |
| `provider`, `uuid`, `share_plus`, `file_picker`, `url_launcher`, `package_info_plus`, `path_provider`, `shared_preferences`, `network_info_plus` | BSD/MIT/Apache | pub.dev |
| Other Dart/Flutter packages from pub.dev | various OSI | Settings → Open-source licenses |

No Google Fonts CDN, Play libraries, analytics, or crash reporters. The F-Droid
recipe excludes `com.google.android.play` and enables R8 so Flutter’s unused
deferred-components Play Core stubs do not ship in the APK.

# Task 2 Report: Extend SftpHelper

## Status

**DONE_WITH_CONCERNS**

## Summary

Extended `SftpHelper` around the Task 1 foundation types so it now exposes a
typed directory listing, reuses a single `SftpClient` per helper instance,
supports mkdir/rename/remove operations, caches Windows drive discovery for the
helper lifetime, and adds optional progress/cancel hooks for uploads and
downloads.

To support those changes safely, the OpenCode remote config import path now
consumes typed entries, while the existing SFTP browser and directory picker
keep using the temporary deprecated `listDirWithType` shim but now reuse a
helper instance and use `RemotePath` for Windows-safe path joins and parent
navigation.

## Commit

- `feat(sftp): typed listing, file ops, reusable client, transfer hooks`

## Changes

### `lib/services/sftp_helper.dart`

- Added `listDir(String path)` returning `List<RemoteFsEntry>`.
- Kept `@Deprecated` `listDirWithType(String path)` as a compatibility shim for
  current UI callers.
- Added `_sftp()` caching so each helper instance reuses one `SftpClient`.
- Added `close()` to release the cached client and reset drive cache.
- Added `mkdir`, `rename`, `removeFile`, and `removeDir`.
- Added `SftpProgress` and `SftpCancelToken`.
- Extended `downloadStream` with optional `onProgress`, `cancelToken`, and
  `knownSize`.
- Extended `upload` with optional `onProgress` and `cancelToken`.
- Normalized helper paths through `RemotePath`.
- Cached `listDrives()` results for the helper lifetime, with
  `forceRefresh`.

### `lib/services/opencode_remote_config_service.dart`

- Switched from `listDirWithType` to typed `listDir`.
- Updated entry matching logic to use `RemoteFsEntry`.
- Closed the helper in a `finally` block so one-off imports do not retain a
  cached SFTP client.
- Switched imports to `package:ssh_app/...`.

### `lib/widgets/sftp_browser.dart`

- Reused a `SftpHelper` instance per active SSH client instead of constructing a
  new helper on each operation.
- Closed the helper in `dispose()`.
- Switched remote path joins and parent navigation to `RemotePath` so Windows
  drive roots behave correctly.
- Kept the deprecated listing shim to avoid the broader UI migration planned for
  Task 5.
- Switched touched imports to `package:ssh_app/...`.

### `lib/widgets/sftp_directory_picker.dart`

- Reused one `SftpHelper` for the widget lifetime.
- Closed the helper in `dispose()`.
- Switched directory navigation to `RemotePath.join` / `RemotePath.parent`.
- Kept the deprecated listing shim for compatibility until the Task 5 UI
  migration.
- Switched touched imports to `package:ssh_app/...`.

## Verification

```text
dart format lib/services/sftp_helper.dart lib/services/opencode_remote_config_service.dart lib/widgets/sftp_browser.dart lib/widgets/sftp_directory_picker.dart
→ formatted 4 files (1 changed)

flutter analyze lib/services/sftp_helper.dart lib/widgets/sftp_browser.dart lib/widgets/sftp_directory_picker.dart lib/services/opencode_remote_config_service.dart
→ No issues found

flutter test
→ 57 tests passed
```

## Concerns

1. The new progress and cancel hooks are implemented in `SftpHelper`, but no UI
   surface consumes them yet by design; Task 5 or a follow-up can expose
   transfer progress and cancellation in the browser UI.
2. I did not add new automated tests for `SftpHelper`. The current verification
   is analyzer plus full suite coverage; focused helper tests would be easier
   once the transfer and listing behavior is exercised through injectable/fake
   SFTP abstractions.

## Files Touched

- `lib/services/sftp_helper.dart`
- `lib/services/opencode_remote_config_service.dart`
- `lib/widgets/sftp_browser.dart`
- `lib/widgets/sftp_directory_picker.dart`
- `.superpowers/sdd/task-2-report.md`

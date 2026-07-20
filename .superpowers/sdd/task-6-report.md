# Task 6 Report: Transfer progress UX (single-file)

## Status

**DONE** (manual Android checklist pending)

## Summary

Completed the remaining single-file transfer progress gaps on top of Tasks 2/4/5.
Download now passes remote `knownSize`, upload totals were verified, failed/cancelled
downloads delete partial local files, SnackBar behavior from Task 5 is unchanged, and
the transfer banner uses determinate progress whenever a total is known (including
0-byte files).

## Files Changed

| File | Change |
|------|--------|
| `lib/providers/sftp_controller.dart` | Delete partial local file after failed/cancelled download |
| `lib/widgets/sftp/sftp_transfer_banner.dart` | Determinate progress when `totalBytes != null` (incl. 0 B) |

## Already in place (verified, no code change)

| Requirement | Location |
|-------------|----------|
| Download passes `knownSize: entry.size` | `SftpController.download` → `SftpHelper.downloadStream` |
| Upload total from `localFile.length()` | `SftpController.upload` + `SftpHelper.upload` |
| SnackBar only on real success / error | `SftpBrowser._showOperationSnackBar` (Task 5) |
| Cancel via banner | `SftpTransferBanner` → `controller.cancelTransfer()` |

## Behavior

### Download progress

- `_startTransfer(totalBytes: entry.size)` seeds the banner before streaming.
- `downloadStream` reports `(transferred, knownSize)` on each chunk.
- When SFTP attrs omit size, banner stays indeterminate with byte count text.

### Upload progress

- `await localFile.length()` inside `_runMutation` sets total before upload.
- Helper reports `(offset, totalBytes)` on each chunk.

### Cancel / failure cleanup

- After a failed download (`false` from `_runMutation`), controller best-effort
  deletes the local target file if it exists.
- Covers cancel (no error SnackBar) and SSH/network errors (error SnackBar).
- Does not restore a pre-existing file overwritten mid-download (out of scope).

### Transfer banner polish

- `LinearProgressIndicator.value` set when total is known (not only when `> 0`).
- 0-byte downloads show `0 B of 0 B` with a full determinate bar.

## Manual Test Checklist (Android → Windows)

**Status: PENDING** — no device run in this session.

- [ ] Upload small file → progress moves → completes → `Uploaded` SnackBar
- [ ] Download file with known size → determinate progress → `Downloaded` SnackBar
- [ ] Cancel mid-download → no success SnackBar → partial file removed locally
- [ ] Disconnect SSH mid-transfer → error SnackBar → partial download removed

## Verification

```bash
dart format lib/providers/sftp_controller.dart lib/widgets/sftp/sftp_transfer_banner.dart
flutter analyze
flutter test
```

| Check | Result |
|-------|--------|
| `dart format` | already formatted |
| `flutter analyze` | `No issues found!` |
| `flutter test` | **60/60 passed** |

## Commit

```text
feat(sftp): single-file transfer progress and cancel
```

## Concerns

- No unit test for partial-file cleanup; would need injectable `SftpHelper` or a
  filesystem temp-dir integration test.
- Failed upload leaves a truncated remote file (brief only required download cleanup).
- Overwriting an existing local file on failed download removes the partial write but
  does not restore the previous contents.

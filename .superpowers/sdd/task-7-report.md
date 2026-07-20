# Task 7 Report: Capped text edit + image preview

## Status

**DONE** (manual SSH/SFTP device validation pending)

## Summary

Added a capped remote byte-read API for previews, wired remote text editing and
image preview into the browser-mode SFTP context sheet, and kept all writes on
the existing SFTP helper path. Preview reads now stop at `512 * 1024` bytes,
reject known oversized files before reading, and abort unknown-length streams
once they exceed the cap.

## Files Changed

| File | Change |
|------|--------|
| `lib/services/sftp_helper.dart` | Added `kSftpPreviewMaxBytes`, `readRemoteBytes`, and `writeRemoteBytes` |
| `lib/providers/sftp_controller.dart` | Added browser preview/edit helper methods that route through `SftpHelper` |
| `lib/widgets/sftp/sftp_text_preview.dart` | Added editable UTF-8 text preview dialog and text extension gating |
| `lib/widgets/sftp/sftp_image_preview.dart` | Added remote image preview dialog using `Image.memory` |
| `lib/widgets/sftp/sftp_entry_list.dart` | Added browser-only `Edit` and `Preview` context actions for supported file types |
| `lib/widgets/sftp_browser.dart` | Wired preview/edit actions to capped reads and remote writes |
| `test/widgets/sftp_preview_extensions_test.dart` | Added focused coverage for preview extension gating |

## Behavior

### Capped remote reads

- `readRemoteBytes(path, {maxBytes})` checks `sftp.stat(path).size` first.
- If the remote size is known and exceeds the cap, it throws before opening the
  file stream.
- If the size is unknown, it reads at most `maxBytes + 1` bytes and throws as
  soon as the stream crosses the cap.

### Text editing

- Supported extensions: `.txt`, `.md`, `.ini`, `.env`, `.json`, `.yaml`,
  `.yml`, `.xml`, `.log`, `.csv`.
- Browser mode shows `Edit` only for supported text files.
- Load failures, oversized files, and binary / invalid UTF-8 content surface as
  SnackBars instead of opening the editor.
- Save writes bytes back through SFTP with truncate+write semantics.

### Image preview

- Supported extensions: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`.
- Browser mode shows `Preview` only for supported image files.
- Preview loads bytes through the capped helper and renders them with
  `Image.memory`.

## Manual Test Checklist (Android -> Windows)

**Status: PENDING** — no live SSH/SFTP manual run in this session.

- [ ] Long-press supported text file -> `Edit` appears -> file loads
- [ ] Save edited text -> remote file updates -> reopen shows new contents
- [ ] Open binary/invalid UTF-8 text-named file -> SnackBar refusal
- [ ] Open supported image -> dialog renders image
- [ ] Open image larger than 512 KB -> SnackBar refusal

## Verification

```bash
dart format lib/services/sftp_helper.dart lib/providers/sftp_controller.dart lib/widgets/sftp_browser.dart lib/widgets/sftp/sftp_entry_list.dart lib/widgets/sftp/sftp_text_preview.dart lib/widgets/sftp/sftp_image_preview.dart test/widgets/sftp_preview_extensions_test.dart
flutter analyze
flutter test
```

| Check | Result |
|-------|--------|
| `dart format` | clean |
| `flutter analyze` | `No issues found!` |
| `flutter test` | **64/64 passed** |

## Commit

```text
feat(sftp): capped remote text edit and image preview
```

## Concerns

- No live SSH/SFTP manual validation was run, so remote-server-specific encoding
  edge cases still need device QA.
- Text preview currently accepts UTF-8 only; legacy encodings are rejected as
  non-previewable.
- Unknown-size remote streams still read up to `maxBytes + 1` bytes before the
  cap rejection can fire, which is intentional for hard enforcement.

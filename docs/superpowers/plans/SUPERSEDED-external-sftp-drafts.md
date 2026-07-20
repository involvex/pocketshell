# Superseded external SFTP / Workstation drafts

The following files (typically under Downloads) are **not** implementation
plans for this repo. Do not implement from them:

1. **Implementierungsplan für die PocketShell Workstation.md** — UX wish list
   that references non-existent `lib/providers/sftp_provider.dart` and
   `lib/screens/sftp_screen.dart`, and schedules fragile terminal `pwd` sync
   and previews before file-ops foundations.
2. **Technische Roadmap für PocketShell SFTP-Optimierungen.md** — empty meta
   stub pointing at a “Studio” tab; no APIs, files, or acceptance criteria.

**Use instead:**
[2026-07-20-sftp-explorer-foundations.md](2026-07-20-sftp-explorer-foundations.md)

That plan targets the real stack (`sftp_helper.dart`, `sftp_browser.dart`,
`sftp_directory_picker.dart`), sequences foundations first, and explicitly
defers split-pane workstation chrome to a separate product decision.

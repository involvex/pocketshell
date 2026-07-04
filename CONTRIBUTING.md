# Contributing to PocketShell

Thank you for your interest in contributing to PocketShell! This guide explains
how to get set up, follow project conventions, and submit changes.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold it.

## Ways to Contribute

- Report bugs and request features via [GitHub Issues](https://github.com/involvex/pocketshell/issues)
- Improve documentation in `docs/` and `README.md`
- Fix bugs or add features with pull requests
- Review open pull requests

## Development Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.2.0)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with Flutter extensions (recommended)

### Getting Started

```bash
git clone https://github.com/involvex/pocketshell.git
cd pocketshell
flutter pub get
flutter run
```

### Quality Checks

Run these before opening a pull request:

```bash
flutter pub get
flutter analyze
flutter test
```

`flutter analyze` is the primary quality gate and must pass with no errors.

## Project Architecture

```
lib/
├── models/     — Data classes (SSHProfile, SSHKey, Snippet, etc.)
├── services/   — Business logic and I/O (ConfigService, BackupService, …)
├── providers/  — ChangeNotifier state (SSHProvider, SettingsProvider, …)
├── screens/    — Top-level pages
└── widgets/    — Reusable UI components
```

Key conventions:

- All persistence goes through `ConfigService` — never call
  `shared_preferences` directly from widgets or providers.
- State mutations must call `notifyListeners()`.
- Guard `BuildContext` usage after `await` with `if (!mounted) return`.
- Use `SSHProvider.addLog()` for user-visible connection events.

See [AGENTS.md](AGENTS.md) and [CLAUDE.md](CLAUDE.md) for detailed guidance.

## Coding Style

- Single quotes for strings
- Explicit return types on all methods
- `package:` imports, grouped: Dart SDK → packages → project
- `PascalCase` classes, `camelCase` members, `snake_case` files
- Keep changes focused — prefer the smallest correct diff

## Pull Request Process

1. Fork the repository and create a branch from `main`.
2. Make your changes with clear commit messages.
3. Ensure `flutter analyze` and `flutter test` pass.
4. Open a pull request using the [PR template](.github/pull_request_template.md).
5. Link related issues (`Fixes #123` or `Closes #123` when applicable).
6. Address review feedback.

### Commit Messages

Use concise, imperative messages:

```
fix(ssh): reconnect after Android background resume
feat(agents): add /model slash command autocomplete
docs: update getting-started guide for Windows hosts
```

## Reporting Bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) and include:

- PocketShell version
- Platform (Android, Windows, etc.)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs from the Logs tab (redact hostnames and credentials)

## Security Issues

Do **not** file public issues for security vulnerabilities. See
[SECURITY.md](SECURITY.md).

## Documentation

User-facing docs are built with MkDocs and published to GitHub Pages.
To preview locally:

```bash
pip install -r .github/requirements-docs.txt
mkdocs serve
```

## Questions

Open a [GitHub Discussion](https://github.com/involvex/pocketshell/discussions)
or issue if you are unsure where to start. We are happy to help.

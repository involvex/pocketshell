# Plan: Update Project Documentation (README, GEMINI, AGENTS)

This plan outlines the updates to `README.md`, `GEMINI.md`, and `AGENTS.md` to reflect the current state of the **ssh_app** project, including newly implemented features and architecture.

## Objective
Provide accurate, comprehensive, and up-to-date documentation for the SSH application, ensuring that both users (README) and developers (GEMINI, AGENTS) have the necessary context.

## Key Files & Context
- `pubspec.yaml`: For dependencies.
- `lib/`: For architecture and feature set (SSH client/server, Key Manager, Profile Manager, Keyboard Shortcuts, Network Discovery).
- `GEMINI.md`: Current developer context.
- `AGENTS.md`: Current agent operating guidelines.
- `README.md`: Current (placeholder) project description.

## Proposed Changes

### 1. `README.md`
- Replace placeholder content with a professional project overview.
- List key features: SSH Client, SSH Server, Key Management, Profile Management, Terminal Emulator (xterm), Keyboard Shortcuts, Network Discovery.
- Add screenshots placeholders.
- Provide "Getting Started" instructions for users.

### 2. `GEMINI.md`
- Update "Main Technologies" with `pointycastle`, `crypto`, `uuid`.
- Expand "Architecture" to include:
    - **`lib/models/`**: `SSHKey`, `SSHProfile`, `KeyboardShortcut`, `Snippet`.
    - **`lib/services/`**: `ConfigService`, `NetworkDiscoveryService`, `SSHKeyGenerator`.
    - **`lib/providers/`**: `SettingsProvider`, `SnippetProvider`, `SSHProvider`.
- Update "Development Conventions" to include:
    - Usage of `SettingsProvider` for app-wide configuration.
    - Handling of SSH Keys and Profiles.
    - Integration of Keyboard Shortcuts.

### 3. `AGENTS.md`
- Synchronize with the updated architecture in `GEMINI.md`.
- Add specific guidance for working with the new providers and services.
- Update the project structure tree.

## Implementation Steps

### Step 1: Update README.md
- Write a comprehensive README with sections: Features, Installation, Usage, and Development.

### Step 2: Update GEMINI.md
- Refine the technology stack and architectural description.
- Add details about the data persistence (via `ConfigService` and `shared_preferences`).

### Step 3: Update AGENTS.md
- Update the "Working with Providers" section.
- Ensure the folder structure and naming conventions are current.

## Verification & Testing
1.  Verify that all three files are updated and correctly formatted.
2.  Ensure that the information in the documentation matches the actual codebase implementation.

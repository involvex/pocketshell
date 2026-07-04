# Security Policy

## Supported Versions

Security fixes are provided for the latest release on the `main` branch.

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| older   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in PocketShell, please report it
responsibly.

**Do not** open a public GitHub issue for security-sensitive reports.

Instead, use one of these channels:

1. [GitHub Security Advisories](https://github.com/involvex/pocketshell/security/advisories/new)
   (preferred)
2. A private email to the maintainers listed on the repository profile

Include as much detail as possible:

- Affected component (SSH client, local server, OpenCode agents, widgets, etc.)
- Steps to reproduce
- Impact assessment (data exposure, credential leakage, remote code execution)
- Platform and app version

## What to Expect

- **Acknowledgement** within 5 business days
- **Initial assessment** within 10 business days
- **Status updates** as the issue is triaged and fixed

We may ask for additional information. When a fix is ready, we will coordinate
disclosure and credit reporters who wish to be acknowledged.

## Scope

In scope:

- Authentication, session handling, and credential storage in the app
- SSH key handling, profile persistence, and backup import/export
- OpenCode agent API integration and remote config import
- Android home-screen widgets and deep-link handling

Out of scope:

- Vulnerabilities in third-party SSH servers you connect to
- Misconfigured hosts, weak passwords, or leaked private keys outside the app
- Social engineering attacks against end users

Thank you for helping keep PocketShell and its users safe.

# Changelog

All notable changes to NotchShelf are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-22

Initial public release candidate.

### Added

- ConceptFab branding: bundle ID `dev.conceptfab.notchshelf`, About view
  aligned with sibling app Clank, and a Buy Me a Coffee link.
- Notch-attached shelf for dropping and retrieving files via drag-and-drop.
- Collapsed-notch tray icon and file count badge.
- Expand on hover near the notch; auto-collapse with configurable delay.
- System-event glow with optional sound and customizable color.
- Preferences: General, Shelf, About.
- Launch at login via `SMAppService`.
- Reduce Motion support.
- macOS App Sandbox with security-scoped bookmark persistence.

### Known limitations

- Distributed ad-hoc signed. Users must remove the quarantine attribute on
  first launch if Gatekeeper blocks it (see `INSTALL.md`). Notarization will
  follow a Developer ID Application certificate purchase.
- File-moving behavior is still recorded as unresolved in `TODO.md`; verify
  drag-out/move behavior before announcing this release publicly.

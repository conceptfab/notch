# Changelog

All notable changes to NotchShelf are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The shelf now spans the notch width: at least 4 square slots sized from the
  physical notch, with Clear and Preferences moved to a bottom bar.
- Stack file counts are shown as a badge on the slot corner.
- Dropping a file anywhere on the expanded shelf is accepted, not only inside
  the dashed outline.

### Fixed

- A second drop while the first is still loading no longer discards the first.
- Launch cleanup removes only missing files from a stack instead of the whole stack.
- Removing a file resets the slot's copy mode, so the next file dropped there
  is moved again by default.
- A drag that outlives its item view no longer leaves the shelf refusing drops.
- Changing the slot preferences re-pads the shelf immediately.

### Performance

- The notification-banner poll filters windows by geometry before looking up
  the owning app, and its timer allows wakeup coalescing.
- Notch geometry is cached and refreshed on screen changes instead of being
  queried several times per render.
- The stack file list is rebuilt only when the stack changes.
- Selection changes no longer re-render every shelf item.
- Removed unused code: `ThumbnailService`, `ShelfWindowModel.shapeSize`,
  drop-target debounce, and an unused glow sound pulse.

## [1.0.1] - 2026-05-23

Direct-download distribution readiness release.

### Added

- ConceptFab branding: bundle ID `dev.conceptfab.notchshelf`, About view
  aligned with sibling app Clank, and a Buy Me a Coffee link.
- Ad-hoc signed DMG distribution pipeline with bundled install guide, license,
  and SHA-256 checksum.

### Fixed

- Release bundles no longer expose the debugger entitlement
  `com.apple.security.get-task-allow`.

### Known limitations

- Distributed ad-hoc signed. Users must remove the quarantine attribute on
  first launch if Gatekeeper blocks it (see `INSTALL.md`). Notarization will
  follow a Developer ID Application certificate purchase.
- File-moving behavior is still recorded as unresolved in `TODO.md`; verify
  drag-out/move behavior before announcing this release publicly.

## [1.0.0] - 2026-05-15

Initial tagged stable build.

### Added

- Notch-attached shelf for dropping and retrieving files via drag-and-drop.
- Collapsed-notch tray icon and file count badge.
- Expand on hover near the notch; auto-collapse with configurable delay.
- System-event glow with optional sound and customizable color.
- Preferences: General, Shelf, About.
- Launch at login via `SMAppService`.
- Reduce Motion support.
- macOS App Sandbox with security-scoped bookmark persistence.

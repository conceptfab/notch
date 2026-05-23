# NotchShelf

A free macOS app that turns your display notch into a tiny file shelf.
Drop files in, drag them out, and the notch stays out of the way until you
need it.

Website: [notchshelf.conceptfab.com](https://notchshelf.conceptfab.com/)

Current version: `1.0.0`

## What It Does

- Drag-and-drop file shelf attached to the system notch.
- Expand on hover, auto-collapse after a configurable delay.
- Optional glow animation and sound on system notification events.
- Customizable glow color and sound toggle in Preferences > General.
- Launch at login.
- macOS App Sandbox; no network, analytics, or telemetry.

## Requirements

- Apple Silicon Mac
- macOS 26 Tahoe or newer
- A display with a notch (built-in MacBook display or compatible external)

## Download

Download the latest build from the GitHub releases page:

[Download NotchShelf](https://github.com/conceptfab/notchshelf/releases/latest)

The app is currently ad-hoc signed. On first launch, macOS Gatekeeper may show
a warning. Right-click `NotchShelf.app`, choose `Open`, and confirm once. See
the [install guide](INSTALL.md) for the full walkthrough.

## Install

1. Download the DMG from the latest release.
2. Drag `NotchShelf.app` to `Applications`.
3. Launch NotchShelf.
4. Enable launch at login if desired in Preferences.

No terminal command is needed if Gatekeeper offers **Open Anyway**. If launch
remains blocked, follow the quarantine-removal step in [INSTALL.md](INSTALL.md).

## Privacy

NotchShelf is deliberately boring here:

- No analytics
- No tracking
- No newsletter
- No paid tier
- No network access at all (no entitlement requested)

Files you drop on the shelf are read through macOS security-scoped bookmarks
and never leave your Mac. See [PRIVACY.md](PRIVACY.md) for details.

## Development

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
scripts/build.sh      # Debug build
scripts/run.sh        # Launch the most recent build
scripts/test.sh       # Run the test suite (Swift + shell contracts)
scripts/distribute.sh # Release build + DMG + SHA-256 checksum
```

## Links

- Website: [notchshelf.conceptfab.com](https://notchshelf.conceptfab.com/)
- Author: [conceptfab.com](https://conceptfab.com/)
- Source: [github.com/conceptfab/notchshelf](https://github.com/conceptfab/notchshelf)
- Install guide: [INSTALL.md](INSTALL.md)
- Support: [Buy Me a Coffee](https://www.buymeacoffee.com/conceptfab)
- Sibling app: [Clank](https://clank.conceptfab.com/)

## License

NotchShelf is released under the [MIT License](LICENSE).

## Acknowledgements

Notch geometry research borrowed from the
[boring.notch](https://github.com/TheBoredTeam/boring.notch) project.

# NotchShelf Distribution Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make NotchShelf shippable as a direct-download release (.dmg) without purchasing a Developer ID — interim distribution while ad-hoc signed.

**Architecture:** Four concerns: (1) repo hygiene + legal/privacy/changelog docs the public will read, (2) **brand alignment with the sibling Clank app** (shared bundle-ID prefix `dev.conceptfab.*`, ASCII copyright, Info.plist arch flags, Buy-Me-a-Coffee resource, Clank-style About view), (3) release build + DMG packaging scripts that produce a reproducible artifact whose layout matches Clank's DMG, (4) user-facing install documentation that covers the Gatekeeper warning every ad-hoc signed app triggers on a fresh Mac. The app's runtime architecture is otherwise untouched — building, sandboxing, and ad-hoc signing already work.

**Tech Stack:** xcodegen, xcodebuild, codesign (`-`), hdiutil (DMG), shasum, Bash, SwiftUI/AppKit (About view rebuild mirroring Clank's `AboutClankView`), XCTest (bundle resources, Info.plist metadata, About-view content).

**Scope Notes:**

- **In scope:** legal docs, packaging pipeline, install docs, About view rebuild, version metadata polish, **ConceptFab brand alignment with the sibling Clank app** (shared bundle-ID prefix, copyright, About-view layout, Info.plist arch flags, DMG layout), quality gates.
- **Permanent deliverable:** `scripts/package-dmg.sh` (DMG builder) and `scripts/distribute.sh` (orchestrator that produces the final `dist/NotchShelf-<version>.dmg`) are committed, executable, and remain in the repo as the canonical way to produce a shippable DMG. Every future release must be cut by running `scripts/distribute.sh` — no ad-hoc local DMG creation.
- **Brand consistency baseline (the sibling app):** `/Users/micz/__DEV__/Clank` ships as `dev.conceptfab.clank`, copyright `Michal Kleniewski` (ASCII), with About-view rows for Version / Author (→ conceptfab.com) / Website (→ `<app>.conceptfab.com`) / Icons / Platform plus a Buy Me a Coffee button, Info.plist flags `LSRequiresNativeExecution=true`, `LSArchitecturePriority=[arm64]`, `NSHighResolutionCapable=true`, and a DMG that contains the .app + INSTALL.md + LICENSE + /Applications symlink. NotchShelf adopts the same conventions so both apps read as products from the same developer **before** a real Developer ID exists.
- **Breaking change accepted:** Phase 2 migrates the bundle ID from `com.notchshelf.NotchShelf` to `dev.conceptfab.notchshelf`. This invalidates the existing sandbox container `~/Library/Containers/com.notchshelf.NotchShelf/`. NotchShelf has not shipped publicly yet, so dev-machine data loss is acceptable. The plan documents the cleanup step rather than writing a migration shim.
- **Out of scope (deferred):** Developer ID Application certificate, notarization, stapling, Sparkle auto-update, Mac App Store, **full bilingual EN/PL localization** (Clank has it; NotchShelf gets it in a follow-up plan), crash reporting (Sentry/Crashlytics), Sparkle EdDSA signatures.
- **Pre-existing blocker (NOT addressed here):** `TODO.md` contains `nie dziala przenoszenie plików!` (file moving doesn't work). Triage and resolve that functional bug **before** announcing the release. This plan deletes `TODO.md` only after explicit confirmation from the user that the bug is fixed or accepted as a known limitation (see Phase 1 Task 5).

---

## File Structure

**Created files:**

- `LICENSE` — MIT license text (ASCII "Michal Kleniewski" to match Clank), repo root
- `PRIVACY.md` — privacy disclosure, repo root
- `CHANGELOG.md` — initial v1.0.0 entry, repo root
- `INSTALL.md` — end-user install guide with quarantine workaround, repo root
- `NotchShelf/Resources/LICENSE.txt` — copy of `LICENSE` bundled into the .app
- `NotchShelf/Resources/buy-me-a-coffee.png` — Buy Me a Coffee button image (217×60), copied from Clank
- `NotchShelfTests/BundleResourceTests.swift` — verifies bundled LICENSE.txt + buy-me-a-coffee.png
- `NotchShelfTests/InfoPlistMetadataTests.swift` — verifies CFBundle* keys, bundle ID, arch flags, copyright
- `NotchShelfTests/AboutViewContentTests.swift` — verifies About view exposes Author/Website/Buy-Me-a-Coffee URLs
- `scripts/release.sh` — Release-configuration build with explicit ad-hoc codesign
- `scripts/package-dmg.sh` — DMG creation with /Applications symlink + bundled INSTALL.md + LICENSE (Clank pattern)
- `scripts/distribute.sh` — orchestrator: clean → release → package → checksum
- `scripts/test-release-scripts.sh` — bash contract tests for the three release scripts

**Modified files:**

- `README.md` — rewrite for end users (features, screenshots, conceptfab links matching Clank)
- `TODO.md` — deleted (Phase 1 Task 5, conditional)
- `project.yml` — bundle ID prefix `com.notchshelf` → `dev.conceptfab`; product bundle ID → `dev.conceptfab.notchshelf`; tests → `dev.conceptfab.notchshelf.tests`; `Resources` group is auto-included
- `NotchShelf/Info.plist` — copyright switched to ASCII, add `CFBundleGetInfoString`, `NSHumanReadableDescription`, `NSHighResolutionCapable`, `LSRequiresNativeExecution`, `LSArchitecturePriority`
- `NotchShelf/App/Preferences/AboutPreferencesView.swift` — full rebuild to mirror Clank's `AboutClankView` (icon + tagline + LabeledContent rows for Version/Author/Website/Icons/Platform + body text + Buy Me a Coffee button); the existing "View License" / "Acknowledgements" buttons remain accessible
- `scripts/test.sh` — append `scripts/test-release-scripts.sh` invocation

---

## Phase 1: Legal & User-Facing Docs

### Task 1: Add LICENSE (MIT)

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Confirm current copyright holder**

Run: `/usr/libexec/PlistBuddy -c "Print :NSHumanReadableCopyright" NotchShelf/Info.plist`
Expected: `Copyright © 2026 Michał Kleniewski. All rights reserved.` (Polish diacritic). Phase 2 Task 7 normalizes it to ASCII to match Clank; `LICENSE` is created with the final ASCII form from the start.

- [ ] **Step 2: Write LICENSE file**

Create `LICENSE` with canonical MIT text, copyright line **identical** to Clank's `LICENSE` (`Copyright (c) 2026 Michal Kleniewski`, no diacritic):

```
MIT License

Copyright (c) 2026 Michal Kleniewski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Verify file matches Clank's**

Run: `head -1 LICENSE && grep '^Copyright' LICENSE && tail -1 LICENSE | tr -d '\n' && echo`
Expected first line: `MIT License`
Expected copyright line: `Copyright (c) 2026 Michal Kleniewski` (must be byte-for-byte identical to `/Users/micz/__DEV__/Clank/LICENSE` line 3).
Expected last line: ends with `SOFTWARE.`

Cross-check:
```bash
diff <(grep '^Copyright' LICENSE) <(grep '^Copyright' /Users/micz/__DEV__/Clank/LICENSE)
```
Expected: no output (files agree on copyright).

- [ ] **Step 4: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT LICENSE"
```

---

### Task 2: Add PRIVACY.md

**Files:**
- Create: `PRIVACY.md`

- [ ] **Step 1: Write privacy disclosure**

Create `PRIVACY.md`. NotchShelf reads only user-selected file URLs through `com.apple.security.files.user-selected.read-write` and uses app-scope/document-scope bookmarks. No network, no telemetry. Be explicit:

```markdown
# Privacy Policy

**Last updated:** 2026-05-22

NotchShelf is a macOS utility that displays a shelf attached to the system
notch for quickly accessing files you drag into it.

## What NotchShelf accesses

- **User-selected files.** Files you drop on the shelf are accessed through
  macOS security-scoped bookmarks. NotchShelf reads only the file URLs you
  explicitly add. Bookmarks are stored locally in the app's sandbox.
- **System notification events (best effort).** NotchShelf observes the local
  notification window appearing on screen to play an optional glow animation.
  No notification content is read, transmitted, or persisted.

## What NotchShelf does NOT do

- **No network access.** NotchShelf does not include any network entitlement
  and makes no HTTP/DNS calls.
- **No analytics or telemetry.** Nothing is reported back to the developer.
- **No third-party SDKs.** The app links only against Apple platform frameworks.
- **No advertising identifiers.**

## Where data lives

- Shelf items, preferences, and security-scoped bookmarks are stored locally
  in `~/Library/Containers/com.notchshelf.NotchShelf/Data/` under the macOS
  App Sandbox. Deleting the app removes all stored data.

## Contact

Questions or concerns: please open an issue on the project repository.
```

- [ ] **Step 2: Sanity check the entitlements claim**

Run: `cat NotchShelf/NotchShelf.entitlements`
Expected: NO `com.apple.security.network.client`, NO `com.apple.security.network.server`. Only sandbox + file-bookmark + user-selected entitlements present. If anything else appears, update PRIVACY.md to match before committing.

- [ ] **Step 3: Commit**

```bash
git add PRIVACY.md
git commit -m "chore: add privacy disclosure"
```

---

### Task 3: Add CHANGELOG.md

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Confirm shipping version**

Run: `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" NotchShelf/Info.plist || grep MARKETING_VERSION project.yml`
Expected: `1.0.0` (from `MARKETING_VERSION: "1.0.0"` in `project.yml`).

- [ ] **Step 2: Write changelog**

Create `CHANGELOG.md`. Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Initial entry summarizes shipped behavior, not git history:

```markdown
# Changelog

All notable changes to NotchShelf are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-22

Initial public release.

### Added
- ConceptFab branding: bundle ID `dev.conceptfab.notchshelf`, About view aligned with sibling app Clank, Buy Me a Coffee link.
- Notch-attached shelf for dropping and retrieving files via drag-and-drop.
- Collapsed-notch tray icon and file count badge.
- Expand on hover near the notch; auto-collapse with configurable delay.
- System-event glow with optional sound and customizable color.
- Preferences: General, Shelf, About.
- Launch at login (via `SMAppService`).
- Reduce Motion support.
- macOS App Sandbox with security-scoped bookmark persistence.

### Known limitations
- Distributed ad-hoc signed. Users must remove the quarantine attribute on
  first launch (see `INSTALL.md`). Notarization will follow a Developer ID
  Application certificate purchase.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "chore: add CHANGELOG with v1.0.0 initial release notes"
```

---

### Task 4: Rewrite README.md

**Files:**
- Modify: `README.md` (currently 3 lines about dev signing)

- [ ] **Step 1: Replace README with user-facing content (Clank-style structure)**

Overwrite `README.md`. The structure mirrors `/Users/micz/__DEV__/Clank/README.md` — short tagline, website line, current version line, **What It Does**, **Requirements**, **Download**, **Install**, **Privacy**, **Development**, **Links**, **License** — so the two sibling apps read consistently:

```markdown
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
- Customizable glow color and sound toggle (Preferences › General).
- Launch at login.
- macOS App Sandbox; no network, no analytics, no telemetry.

## Requirements

- Apple Silicon Mac
- macOS 26 Tahoe or newer
- A display with a notch (built-in MacBook display or compatible external)

## Download

Download the latest build from the GitHub releases page:

[Download NotchShelf](https://github.com/conceptfab/notchshelf/releases/latest)

The app is currently unsigned (ad-hoc only). On first launch, macOS Gatekeeper
will show a warning. Right-click `NotchShelf.app`, choose `Open`, and confirm
once. See the [install guide](INSTALL.md) for the full walkthrough.

## Install

1. Download the DMG from the latest release.
2. Drag `NotchShelf.app` to `Applications`.
3. Launch NotchShelf.
4. Approve launch-at-login when prompted (optional, in Preferences).

No terminal command is needed for normal installation, though one may help if
Gatekeeper is stubborn — see [INSTALL.md](INSTALL.md).

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
```

- [ ] **Step 2: Verify**

Run: `wc -l README.md && grep -c '^## ' README.md && grep -c 'conceptfab' README.md`
Expected: README has ~80+ lines; at least 7 second-level headings (`What It Does`, `Requirements`, `Download`, `Install`, `Privacy`, `Development`, `Links`, `License`, `Acknowledgements`); at least 4 mentions of `conceptfab` (Website, Author, Source, Buy Me a Coffee).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for end users"
```

---

### Task 5: Add INSTALL.md and remove TODO.md

**Files:**
- Create: `INSTALL.md`
- Delete: `TODO.md`

> **STOP before deleting TODO.md.** `TODO.md` reads `nie dziala przenoszenie plików!` — file moving doesn't work. Confirm with the user that this is either fixed (separate work) or explicitly accepted as a known limitation listed in `CHANGELOG.md`. If neither is true, **do not delete** `TODO.md`; abort Step 3 of this task and continue with the rest of the plan.

- [ ] **Step 1: Write INSTALL.md**

Create `INSTALL.md`:

```markdown
# Installing NotchShelf

NotchShelf 1.0 is distributed ad-hoc signed (no Apple Developer ID yet).
macOS Gatekeeper will refuse to open it on first launch with a message like
"NotchShelf is damaged and can't be opened" or "cannot be opened because the
developer cannot be verified". This is expected — the binary is fine, macOS
just hasn't been told to trust ad-hoc signed apps from the internet.

## One-time setup (recommended)

1. Open the downloaded `NotchShelf-<version>.dmg`.
2. Drag **NotchShelf.app** into the `/Applications` folder shown in the
   window.
3. Eject the DMG.
4. Open **Terminal** and run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchShelf.app
   ```

5. Launch NotchShelf from Spotlight, Launchpad, or `/Applications`.

## Alternative: right-click → Open

If you prefer not to use Terminal:

1. Drag **NotchShelf.app** into `/Applications`.
2. Right-click (or Control-click) **NotchShelf.app** and choose **Open**.
3. In the dialog that appears, click **Open** again.
4. If macOS still refuses, open **System Settings › Privacy & Security**,
   scroll down to the "NotchShelf was blocked" notice, and click
   **Open Anyway**.

## Verifying the download (optional)

Each release publishes a `NotchShelf-<version>.dmg.sha256` file. Verify the
DMG before installing:

```bash
shasum -a 256 -c NotchShelf-<version>.dmg.sha256
```

Expected output: `NotchShelf-<version>.dmg: OK`.

## Uninstalling

1. Quit NotchShelf from its preferences window.
2. Drag `/Applications/NotchShelf.app` to the Trash.
3. Optional — remove the app's local data:

   ```bash
   rm -rf ~/Library/Containers/com.notchshelf.NotchShelf
   ```

4. Optional — remove the launch-at-login agent if you used `scripts/install-autostart.sh`:

   ```bash
   scripts/install-autostart.sh uninstall
   ```
```

- [ ] **Step 2: Verify**

Run: `grep -c '^##' INSTALL.md`
Expected: `4` (One-time setup, Alternative, Verifying, Uninstalling)

- [ ] **Step 3: Delete TODO.md (CONDITIONAL — see top of task)**

If and only if the user confirmed the file-move bug is resolved or documented:

```bash
git rm TODO.md
```

Otherwise leave `TODO.md` in place and skip this step.

- [ ] **Step 4: Commit**

```bash
git add INSTALL.md
git commit -m "docs: add INSTALL.md with quarantine workaround"
```

---

## Phase 2: ConceptFab Brand Alignment

This phase aligns NotchShelf's identity with sibling app **Clank** (`/Users/micz/__DEV__/Clank`): shared bundle-ID prefix `dev.conceptfab.*`, ASCII copyright, Info.plist arch flags, bundled `LICENSE.txt` + `buy-me-a-coffee.png`, and an About view that visually matches Clank's `AboutClankView`.

### Task 6: Migrate bundle identifier to `dev.conceptfab.notchshelf`

**Files:**
- Modify: `project.yml`

> Reference: Clank's `Info.plist` declares `CFBundleIdentifier = dev.conceptfab.clank`. We mirror the same `dev.conceptfab.*` prefix here. **This invalidates the existing sandbox container on the dev machine** — that is the accepted breaking change called out in Scope Notes.

- [ ] **Step 1: Update project.yml**

Edit `project.yml`. Make three changes:

1. `bundleIdPrefix: com.notchshelf` → `bundleIdPrefix: dev.conceptfab`
2. In the `NotchShelf` target's `settings.base`, `PRODUCT_BUNDLE_IDENTIFIER: com.notchshelf.NotchShelf` → `PRODUCT_BUNDLE_IDENTIFIER: dev.conceptfab.notchshelf`
3. In the `NotchShelfTests` target's `settings.base`, `PRODUCT_BUNDLE_IDENTIFIER: com.notchshelf.NotchShelfTests` → `PRODUCT_BUNDLE_IDENTIFIER: dev.conceptfab.notchshelf.tests`

After editing, the relevant fragments should read:

```yaml
options:
  bundleIdPrefix: dev.conceptfab
  ...
targets:
  NotchShelf:
    ...
    settings:
      base:
        ...
        PRODUCT_BUNDLE_IDENTIFIER: dev.conceptfab.notchshelf
        ...
  NotchShelfTests:
    ...
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.conceptfab.notchshelf.tests
```

- [ ] **Step 2: Update the autostart LaunchAgent label**

Edit `scripts/install-autostart.sh`. Change:

```bash
LABEL="com.notchshelf.NotchShelf.autostart"
```

to:

```bash
LABEL="dev.conceptfab.notchshelf.autostart"
```

(If the user has an old LaunchAgent installed under the previous label, they'll re-run `scripts/install-autostart.sh uninstall` with the old script first — document this in the commit message.)

- [ ] **Step 3: Clear the old sandbox container and old LaunchAgent**

```bash
# Remove the old sandbox container so the next launch starts clean.
rm -rf ~/Library/Containers/com.notchshelf.NotchShelf

# Remove the old LaunchAgent if previously installed.
launchctl bootout "gui/$UID" "$HOME/Library/LaunchAgents/com.notchshelf.NotchShelf.autostart.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.notchshelf.NotchShelf.autostart.plist"
```

- [ ] **Step 4: Regenerate the project and verify the new bundle ID**

```bash
xcodegen generate
scripts/build.sh
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" .build/Build/Products/Debug/NotchShelf.app/Contents/Info.plist
```

Expected: `dev.conceptfab.notchshelf`.

- [ ] **Step 5: Run the test suite**

Run: `scripts/test.sh 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`, 121 baseline tests still pass under the new bundle ID. (The XCTest harness reads the test-target bundle ID, which we also updated.)

- [ ] **Step 6: Commit**

```bash
git add project.yml scripts/install-autostart.sh
git commit -m "chore: migrate bundle ID to dev.conceptfab.notchshelf"
```

---

### Task 7: Info.plist — ASCII copyright + ConceptFab metadata + arm64-native flags

**Files:**
- Modify: `NotchShelf/Info.plist`
- Create: `NotchShelfTests/InfoPlistMetadataTests.swift`

This task absorbs the metadata-polish work and adds the three Info.plist flags Clank uses (`NSHighResolutionCapable`, `LSRequiresNativeExecution`, `LSArchitecturePriority`) plus the bundle-ID assertion and ASCII copyright string.

- [ ] **Step 1: Write the failing test first**

Create `NotchShelfTests/InfoPlistMetadataTests.swift`:

```swift
import XCTest

final class InfoPlistMetadataTests: XCTestCase {
    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    func testBundleIdentifierIsConceptFabNamespace() throws {
        let bundleId = try XCTUnwrap(info["CFBundleIdentifier"] as? String)
        XCTAssertEqual(bundleId, "dev.conceptfab.notchshelf")
    }

    func testCopyrightIsAsciiAndMatchesClank() throws {
        let copyright = try XCTUnwrap(info["NSHumanReadableCopyright"] as? String)
        XCTAssertEqual(copyright, "Copyright © 2026 Michal Kleniewski. All rights reserved.")
        XCTAssertFalse(copyright.contains("Michał"), "copyright must use ASCII 'Michal' to match Clank")
    }

    func testGetInfoStringContainsVersionAndAsciiAuthor() throws {
        let getInfo = try XCTUnwrap(info["CFBundleGetInfoString"] as? String)
        let version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)
        XCTAssertTrue(getInfo.contains(version))
        XCTAssertTrue(getInfo.contains("Michal Kleniewski"), "must use ASCII author name")
    }

    func testHumanReadableDescriptionIsPresent() throws {
        let description = try XCTUnwrap(info["NSHumanReadableDescription"] as? String)
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.lowercased().contains("notch"))
    }

    func testApplicationCategory() throws {
        let category = try XCTUnwrap(info["LSApplicationCategoryType"] as? String)
        XCTAssertEqual(category, "public.app-category.utilities")
    }

    func testIsAgentApp() throws {
        let isUIElement = try XCTUnwrap(info["LSUIElement"] as? Bool)
        XCTAssertTrue(isUIElement)
    }

    func testHighResolutionCapable() throws {
        let highRes = try XCTUnwrap(info["NSHighResolutionCapable"] as? Bool)
        XCTAssertTrue(highRes)
    }

    func testRequiresNativeExecution() throws {
        let nativeOnly = try XCTUnwrap(info["LSRequiresNativeExecution"] as? Bool)
        XCTAssertTrue(nativeOnly, "NotchShelf is Apple Silicon only; refuse Rosetta translation")
    }

    func testArchitecturePriorityIsArm64Only() throws {
        let priority = try XCTUnwrap(info["LSArchitecturePriority"] as? [String])
        XCTAssertEqual(priority, ["arm64"])
    }
}
```

- [ ] **Step 2: Run the test — expect failures**

Run: `scripts/test.sh 2>&1 | grep -E '(InfoPlistMetadataTests|TEST)' | tail -20`
Expected: most `InfoPlistMetadataTests` cases FAIL (`CFBundleGetInfoString`, `NSHumanReadableDescription`, `NSHighResolutionCapable`, `LSRequiresNativeExecution`, `LSArchitecturePriority` are missing; copyright still has the Polish diacritic).

- [ ] **Step 3: Update Info.plist**

Edit `NotchShelf/Info.plist`. Replace the `NSHumanReadableCopyright` entry and add the new keys. The full top-level `<dict>` should look like this after the edit:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NotchShelf</string>
    <key>CFBundleDisplayName</key>
    <string>NotchShelf</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundleGetInfoString</key>
    <string>NotchShelf $(MARKETING_VERSION), © 2026 Michal Kleniewski</string>
    <key>NSHumanReadableDescription</key>
    <string>A shelf that lives in the macOS notch for quick file drag-and-drop.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Michal Kleniewski. All rights reserved.</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Run the test — expect PASS**

Run: `scripts/test.sh 2>&1 | grep -E '(InfoPlistMetadataTests|TEST)' | tail -20`
Expected: all nine `InfoPlistMetadataTests` cases PASS. Final line: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Info.plist NotchShelfTests/InfoPlistMetadataTests.swift
git commit -m "chore: align Info.plist with Clank (ASCII copyright, arm64-native, hi-res, get-info)"
```

---

### Task 8: Bundle LICENSE.txt and buy-me-a-coffee.png

**Files:**
- Create: `NotchShelf/Resources/LICENSE.txt`
- Create: `NotchShelf/Resources/buy-me-a-coffee.png` (copied from Clank's resources)

- [ ] **Step 1: Confirm the source asset exists in Clank**

Run: `ls -la /Users/micz/__DEV__/Clank/Sources/Clank/Resources/buy-me-a-coffee.png && file /Users/micz/__DEV__/Clank/Sources/Clank/Resources/buy-me-a-coffee.png`
Expected: file exists, `file` reports `PNG image data`.

- [ ] **Step 2: Copy resources into the NotchShelf target**

```bash
mkdir -p NotchShelf/Resources
cp LICENSE NotchShelf/Resources/LICENSE.txt
cp /Users/micz/__DEV__/Clank/Sources/Clank/Resources/buy-me-a-coffee.png NotchShelf/Resources/buy-me-a-coffee.png
```

- [ ] **Step 3: Regenerate the Xcode project and build**

```bash
xcodegen generate
scripts/build.sh
```

Expected: xcodegen picks up the new `Resources/` directory automatically (the `NotchShelf/` source path is already recursive). Build succeeds.

- [ ] **Step 4: Verify the resources are inside the app bundle**

```bash
ls .build/Build/Products/Debug/NotchShelf.app/Contents/Resources/LICENSE.txt
ls .build/Build/Products/Debug/NotchShelf.app/Contents/Resources/buy-me-a-coffee.png
```

Expected: both files exist.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Resources/LICENSE.txt NotchShelf/Resources/buy-me-a-coffee.png
git commit -m "chore: bundle LICENSE.txt and Buy Me a Coffee image"
```

---

### Task 9: Tests for bundled resources

**Files:**
- Create: `NotchShelfTests/BundleResourceTests.swift`

- [ ] **Step 1: Write the test**

Create `NotchShelfTests/BundleResourceTests.swift`:

```swift
import XCTest
import AppKit
@testable import NotchShelf

final class BundleResourceTests: XCTestCase {
    func testLicenseTextIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
            "LICENSE.txt must be bundled in the app's Resources"
        )

        let contents = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(contents.hasPrefix("MIT License"))
        XCTAssertTrue(
            contents.contains("Michal Kleniewski"),
            "LICENSE.txt must use ASCII author name to match Clank"
        )
    }

    func testBuyMeACoffeeImageIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "buy-me-a-coffee", withExtension: "png"),
            "buy-me-a-coffee.png must be bundled"
        )

        let image = try XCTUnwrap(NSImage(contentsOf: url), "must be a readable PNG")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}
```

- [ ] **Step 2: Run the test**

Run: `scripts/test.sh 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` and `BundleResourceTests` passes.

- [ ] **Step 3: Commit**

```bash
git add NotchShelfTests/BundleResourceTests.swift
git commit -m "test: verify LICENSE.txt and buy-me-a-coffee.png are bundled"
```

---

### Task 10: Rebuild the About view to mirror Clank's `AboutClankView`

**Files:**
- Modify: `NotchShelf/App/Preferences/AboutPreferencesView.swift` (full replacement of the `body` and helpers; keep file name and `struct AboutPreferencesView: View`)

Reference layout — `/Users/micz/__DEV__/Clank/Sources/Clank/SettingsWindowController.swift:510-596` (`AboutClankView`). NotchShelf adopts the same structure: icon at top → app name (largeTitle bold) → tagline → LabeledContent rows (Version / Author / Website / Icons / Platform) → body text → Buy Me a Coffee button. The existing **View License** and **Acknowledgements** buttons stay (they're useful, Clank just doesn't have them).

- [ ] **Step 1: Write the failing About-view content test**

Create `NotchShelfTests/AboutViewContentTests.swift`:

```swift
import XCTest
@testable import NotchShelf

final class AboutViewContentTests: XCTestCase {
    func testAboutLinksPointToConceptFab() {
        XCTAssertEqual(
            AboutPreferencesView.authorURL,
            URL(string: "https://conceptfab.com")
        )
        XCTAssertEqual(
            AboutPreferencesView.websiteURL,
            URL(string: "https://notchshelf.conceptfab.com")
        )
        XCTAssertEqual(
            AboutPreferencesView.buyMeACoffeeURL,
            URL(string: "https://www.buymeacoffee.com/conceptfab")
        )
    }

    func testAboutPlatformText() {
        XCTAssertEqual(
            AboutPreferencesView.platformDescription,
            "Apple Silicon Mac, macOS 26+"
        )
    }

    func testAboutTaglineIsNonEmpty() {
        XCTAssertFalse(AboutPreferencesView.tagline.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test — expect failures**

Run: `scripts/test.sh 2>&1 | grep -E '(AboutViewContentTests|TEST)' | tail -10`
Expected: all four cases FAIL (the static URLs and strings don't exist yet).

- [ ] **Step 3: Rewrite `AboutPreferencesView.swift`**

Overwrite `NotchShelf/App/Preferences/AboutPreferencesView.swift` with the Clank-aligned layout:

```swift
import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    static let authorURL = URL(string: "https://conceptfab.com")!
    static let websiteURL = URL(string: "https://notchshelf.conceptfab.com")!
    static let buyMeACoffeeURL = URL(string: "https://www.buymeacoffee.com/conceptfab")!
    static let platformDescription = "Apple Silicon Mac, macOS 26+"
    static let tagline = "A shelf that lives in the macOS notch."

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }

    private var appIcon: NSImage {
        if
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        {
            return icon
        }
        if let icon = NSApp.applicationIconImage, icon.isValid {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    var body: some View {
        PreferencesPage {
            VStack(spacing: 16) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("NotchShelf")
                        .font(.largeTitle.bold())
                    Text(Self.tagline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Version") {
                        Text(versionString).foregroundStyle(.secondary)
                    }
                    LabeledContent("Author") {
                        Link("conceptfab.com", destination: Self.authorURL)
                    }
                    LabeledContent("Website") {
                        Link("notchshelf.conceptfab.com", destination: Self.websiteURL)
                    }
                    LabeledContent("Icons") {
                        Text("MW Coffee").foregroundStyle(.secondary)
                    }
                    LabeledContent("Platform") {
                        Text(Self.platformDescription).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: 360)

                Text(copyright)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link(destination: Self.buyMeACoffeeURL) {
                    buyMeACoffeeButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buy Me a Coffee")
                .padding(.top, 2)

                HStack(spacing: 12) {
                    Button {
                        openBundledLicense()
                    } label: {
                        Text("View License")
                    }

                    Button {
                        showAcknowledgements()
                    } label: {
                        Text("Acknowledgements")
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
    }

    private var buyMeACoffeeButton: some View {
        Group {
            if
                let url = Bundle.main.url(forResource: "buy-me-a-coffee", withExtension: "png"),
                let image = NSImage(contentsOf: url)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 217, height: 60)
            } else {
                Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    .frame(minWidth: 180)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    private func openBundledLicense() {
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") {
            NSWorkspace.shared.open(url)
            return
        }
        let alert = NSAlert()
        alert.messageText = "License file not found"
        alert.informativeText = "NotchShelf is distributed under the MIT License."
        alert.runModal()
    }

    private func showAcknowledgements() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "NotchShelf is built on Apple platform frameworks only. Thanks to the boring.notch project for the notch geometry research, and to ConceptFab's sibling app Clank for the About-view layout."
        alert.runModal()
    }
}
```

- [ ] **Step 4: Run the test — expect PASS**

Run: `scripts/test.sh 2>&1 | grep -E '(AboutViewContentTests|TEST)' | tail -10`
Expected: all four `AboutViewContentTests` cases PASS. Final line: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Smoke test the UI**

```bash
scripts/run.sh
```

Open Preferences › About manually. Verify:
- The icon, **NotchShelf** title and tagline render at the top.
- Rows show Version, Author (`conceptfab.com` clickable), Website (`notchshelf.conceptfab.com` clickable), Icons (`MW Coffee`), Platform (`Apple Silicon Mac, macOS 26+`).
- The Buy Me a Coffee yellow image button renders below the copyright. Clicking opens `https://www.buymeacoffee.com/conceptfab` in the default browser.
- **View License** opens the bundled `LICENSE.txt`.
- **Acknowledgements** shows the updated text mentioning Clank.

Quit the app afterwards (`killall NotchShelf`).

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/App/Preferences/AboutPreferencesView.swift NotchShelfTests/AboutViewContentTests.swift
git commit -m "feat(about): rebuild About view to mirror Clank's AboutClankView"
```

---

## Phase 3: Release Build & Packaging Pipeline

### Task 11: Add scripts/release.sh

**Files:**
- Create: `scripts/release.sh`

- [ ] **Step 1: Write the Release build script**

Create `scripts/release.sh`:

```bash
#!/usr/bin/env bash
# Builds NotchShelf in Release configuration with explicit ad-hoc signing.
# Output: $RELEASE_DIR/NotchShelf.app (default: dist/NotchShelf.app)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="Release"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build-release}"
RELEASE_DIR="${RELEASE_DIR:-dist}"
PROJECT_PATH="NotchShelf.xcodeproj"
SCHEME="NotchShelf"
BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/NotchShelf.app"
OUTPUT_APP="$RELEASE_DIR/NotchShelf.app"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

echo "==> Regenerating Xcode project..."
xcodegen generate

echo "==> Cleaning previous Release output..."
rm -rf "$DERIVED_DATA_PATH" "$OUTPUT_APP"
mkdir -p "$RELEASE_DIR"

echo "==> Building Release configuration..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: expected built app at $BUILT_APP, but it is missing" >&2
  exit 1
fi

echo "==> Copying built app to $OUTPUT_APP..."
ditto "$BUILT_APP" "$OUTPUT_APP"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
codesign -dvv "$OUTPUT_APP" 2>&1 | grep -E '^(Identifier|Authority|Signature|TeamIdentifier)='

echo "==> Verifying hardened runtime flag..."
codesign -d --entitlements - "$OUTPUT_APP" >/dev/null

echo
echo "Release build complete: $OUTPUT_APP"
echo "Next: scripts/package-dmg.sh"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/release.sh
```

- [ ] **Step 3: Run it end-to-end**

Run: `scripts/release.sh 2>&1 | tail -20`
Expected: ends with `Release build complete: dist/NotchShelf.app` and `codesign --verify` reports the app as valid.

- [ ] **Step 4: Inspect output**

```bash
ls dist/NotchShelf.app/Contents/MacOS/
file dist/NotchShelf.app/Contents/MacOS/NotchShelf
```

Expected: `NotchShelf` binary exists; `file` reports `Mach-O 64-bit executable arm64` (or `universal binary` if multi-arch).

- [ ] **Step 5: Commit**

```bash
git add scripts/release.sh
git commit -m "build: add scripts/release.sh for Release-config builds with ad-hoc signing"
```

---

### Task 12: Add scripts/package-dmg.sh (Clank-style DMG contents)

**Files:**
- Create: `scripts/package-dmg.sh`

Matches Clank's DMG layout (`/Users/micz/__DEV__/Clank/scripts/build-dmg.sh`): the DMG window contains the .app, an `/Applications` symlink for drag-install, and copies of `INSTALL.md` and `LICENSE` so users can read them straight from the mounted disk.

- [ ] **Step 1: Write the DMG packaging script**

Create `scripts/package-dmg.sh`:

```bash
#!/usr/bin/env bash
# Packages dist/NotchShelf.app into dist/NotchShelf-<version>.dmg with:
#   - /Applications symlink (drag-install)
#   - INSTALL.md (Gatekeeper workaround for end users)
#   - LICENSE   (MIT)
# Layout mirrors the sibling Clank app for visual/structural consistency.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_DIR="${RELEASE_DIR:-dist}"
APP_PATH="$RELEASE_DIR/NotchShelf.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: $APP_PATH not found. Run scripts/release.sh first." >&2
  exit 1
fi

for required in INSTALL.md LICENSE; do
  if [[ ! -f "$required" ]]; then
    echo "error: $required missing — Phase 1 must complete first." >&2
    exit 1
  fi
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DMG_NAME="NotchShelf-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
STAGING_DIR="$(mktemp -d -t notchshelf-dmg.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> Staging DMG contents in $STAGING_DIR..."
ditto "$APP_PATH" "$STAGING_DIR/NotchShelf.app"
cp INSTALL.md "$STAGING_DIR/INSTALL.md"
cp LICENSE "$STAGING_DIR/LICENSE"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"

echo "==> Creating compressed DMG: $DMG_PATH"
hdiutil create \
  -volname "NotchShelf $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG_PATH"

echo "==> Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo
echo "Packaged: $DMG_PATH"
ls -lh "$DMG_PATH"
echo "Next: scripts/distribute.sh (full pipeline) or shasum manually."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/package-dmg.sh
```

- [ ] **Step 3: Run it (requires Task 11 output)**

Run: `scripts/package-dmg.sh 2>&1 | tail -10`
Expected: ends with `Packaged: dist/NotchShelf-1.0.0.dmg` and a `ls -lh` line showing file size.

- [ ] **Step 4: Smoke test the DMG contents (must match Clank layout)**

```bash
hdiutil attach -nobrowse dist/NotchShelf-1.0.0.dmg
ls /Volumes/NotchShelf*/
hdiutil detach /Volumes/NotchShelf*
```

Expected: `ls` shows exactly four entries — `Applications` (symlink), `INSTALL.md`, `LICENSE`, `NotchShelf.app`. Then unmounted cleanly.

- [ ] **Step 5: Commit**

```bash
git add scripts/package-dmg.sh
git commit -m "build: add scripts/package-dmg.sh (Clank-style DMG with INSTALL.md + LICENSE)"
```

---

### Task 13: Add scripts/distribute.sh orchestrator + checksum

**Files:**
- Create: `scripts/distribute.sh`

- [ ] **Step 1: Write the orchestrator**

Create `scripts/distribute.sh`:

```bash
#!/usr/bin/env bash
# End-to-end release pipeline:
#   1. Run the full test suite
#   2. Build the Release-configuration .app (scripts/release.sh)
#   3. Package it as a DMG (scripts/package-dmg.sh)
#   4. Compute and write a SHA-256 checksum file next to the DMG
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_DIR="${RELEASE_DIR:-dist}"

echo "==> [1/4] Running tests..."
scripts/test.sh

echo "==> [2/4] Building Release..."
scripts/release.sh

echo "==> [3/4] Packaging DMG..."
scripts/package-dmg.sh

DMG_PATH="$(ls -1t "$RELEASE_DIR"/NotchShelf-*.dmg | head -1)"
if [[ -z "$DMG_PATH" ]]; then
  echo "error: no DMG produced in $RELEASE_DIR" >&2
  exit 1
fi

CHECKSUM_PATH="$DMG_PATH.sha256"
echo "==> [4/4] Computing SHA-256 → $CHECKSUM_PATH"
(cd "$RELEASE_DIR" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")")

echo
echo "Release artifacts:"
ls -la "$DMG_PATH" "$CHECKSUM_PATH"
echo
echo "Verify on a clean machine with:"
echo "  shasum -a 256 -c $(basename "$CHECKSUM_PATH")"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/distribute.sh
```

- [ ] **Step 3: Run the full pipeline**

Run: `scripts/distribute.sh 2>&1 | tail -15`
Expected: ends with `Release artifacts:` and two file listings (`.dmg` and `.dmg.sha256`).

- [ ] **Step 4: Verify the checksum file format**

```bash
cat dist/NotchShelf-1.0.0.dmg.sha256
shasum -a 256 -c dist/NotchShelf-1.0.0.dmg.sha256
```

Expected: file contains one line of the form `<64-hex>  NotchShelf-1.0.0.dmg`. `shasum -c` reports `NotchShelf-1.0.0.dmg: OK`.

> Note: `shasum -c` must be run from the `dist/` directory (or with that directory as CWD) because the checksum file uses a relative filename. Document this in the verification step.

- [ ] **Step 5: Add dist/ to .gitignore**

Edit `.gitignore`. Add under the existing "Derived Data & Build" section:

```
# Release artifacts produced by scripts/distribute.sh
dist/
.build-release/
```

- [ ] **Step 6: Commit**

```bash
git add scripts/distribute.sh .gitignore
git commit -m "build: add scripts/distribute.sh end-to-end release pipeline"
```

---

### Task 14: Bash contract tests for the release scripts

**Files:**
- Create: `scripts/test-release-scripts.sh`
- Modify: `scripts/test.sh` (append invocation)

These tests verify the scripts exist, are executable, and surface required commands — they do not run the actual builds (xcodebuild is far too slow for a unit test). Follows the same pattern as the existing `scripts/test-trigger-system-event.sh`.

- [ ] **Step 1: Write the contract test**

Create `scripts/test-release-scripts.sh`:

```bash
#!/usr/bin/env bash
# Contract tests for scripts/release.sh, scripts/package-dmg.sh, scripts/distribute.sh.
# Verifies invariants the rest of the pipeline depends on without running xcodebuild.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

assert_exec() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "FAIL: $path is not executable"
    failures=$((failures + 1))
  fi
}

assert_contains() {
  local path="$1" needle="$2" label="$3"
  if ! grep -qF "$needle" "$path"; then
    echo "FAIL: $label — '$path' must contain: $needle"
    failures=$((failures + 1))
  fi
}

# release.sh contract
assert_exec scripts/release.sh
assert_contains scripts/release.sh 'CODE_SIGN_IDENTITY="-"' 'release.sh signs ad-hoc'
assert_contains scripts/release.sh '-configuration "$CONFIGURATION"' 'release.sh passes configuration to xcodebuild'
assert_contains scripts/release.sh 'codesign --verify' 'release.sh verifies the signature'

# package-dmg.sh contract
assert_exec scripts/package-dmg.sh
assert_contains scripts/package-dmg.sh 'hdiutil create' 'package-dmg.sh creates a DMG'
assert_contains scripts/package-dmg.sh 'ln -s /Applications' 'package-dmg.sh adds /Applications symlink'
assert_contains scripts/package-dmg.sh 'CFBundleShortVersionString' 'package-dmg.sh reads version from Info.plist'

# distribute.sh contract
assert_exec scripts/distribute.sh
assert_contains scripts/distribute.sh 'scripts/test.sh' 'distribute.sh runs the test suite'
assert_contains scripts/distribute.sh 'scripts/release.sh' 'distribute.sh runs release build'
assert_contains scripts/distribute.sh 'scripts/package-dmg.sh' 'distribute.sh runs DMG packaging'
assert_contains scripts/distribute.sh 'shasum -a 256' 'distribute.sh writes SHA-256 checksum'

if (( failures > 0 )); then
  echo
  echo "scripts/test-release-scripts.sh: $failures failure(s)"
  exit 1
fi

echo "scripts/test-release-scripts.sh: OK"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/test-release-scripts.sh
```

- [ ] **Step 3: Run it directly**

Run: `scripts/test-release-scripts.sh`
Expected: `scripts/test-release-scripts.sh: OK`. Exit code 0.

- [ ] **Step 4: Wire into scripts/test.sh**

Edit `scripts/test.sh`. The current file ends with the `xcodebuild test` invocation. Add the new contract test right after the existing trigger-event contract test, before `xcodebuild test`:

```bash
"$ROOT_DIR/scripts/test-trigger-system-event.sh"
"$ROOT_DIR/scripts/test-release-scripts.sh"
xcodebuild test \
  ...
```

(Replace the entire block of three lines around `xcodebuild test` so both shell contracts run before the Swift tests.)

- [ ] **Step 5: Run the full test suite**

Run: `scripts/test.sh 2>&1 | tail -5`
Expected: both shell contracts print `OK`, then `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add scripts/test-release-scripts.sh scripts/test.sh
git commit -m "test: add contract tests for release/package-dmg/distribute scripts"
```

---

## Phase 4: Quality Gates

### Task 15: Release-build hygiene audit

**Files:**
- Inspect only (no edits unless a finding is uncovered).

This task is a checklist run. If a finding requires a code change, write a focused commit; otherwise note "no findings" in the PR description.

- [ ] **Step 1: Confirm no `print()` debug statements ship in Release**

Run:

```bash
grep -RIn '\bprint(' NotchShelf --include='*.swift' | grep -v '// ok-print:' || echo "no bare print() calls in production sources"
```

Expected: `no bare print() calls in production sources`. If anything appears, replace it with `AppLogger.<category>.debug(...)` (the project already standardizes on `AppLogger`).

- [ ] **Step 2: Confirm there are no leftover `#if DEBUG` overrides hardcoding test behavior in Release**

Run:

```bash
grep -RIn '#if DEBUG' NotchShelf --include='*.swift'
```

Expected: results, if any, must be reviewed manually. Confirm each `#if DEBUG` block contains only diagnostic helpers — none must change shipping behavior in a way that breaks Release.

- [ ] **Step 3: Confirm `LSMinimumSystemVersion` is correct for the deployment target**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' dist/NotchShelf.app/Contents/Info.plist
```

Expected: `26.0` (matches `project.yml deploymentTarget.macOS: "26.0"`). If different, the macro substitution failed — investigate `project.yml`.

- [ ] **Step 4: Run the app from /Applications**

```bash
killall NotchShelf 2>/dev/null || true
rm -rf /Applications/NotchShelf.app
cp -R dist/NotchShelf.app /Applications/NotchShelf.app
xattr -dr com.apple.quarantine /Applications/NotchShelf.app  # in case Safari/curl added it
open /Applications/NotchShelf.app
sleep 2
pgrep -x NotchShelf >/dev/null && echo "running" || echo "NOT running — investigate Console.app"
```

Expected: `running`. Open Preferences › About; verify version shows `1.0.0 (100)` and clicking **View License** opens `LICENSE.txt`. Drag a file onto the notch, then drag it back out. Quit the app afterwards.

- [ ] **Step 5: Record findings**

If any of Steps 1–4 surfaced an issue, fix it in a focused commit. Otherwise no commit is needed for this task.

---

### Task 16: Final regression and release smoke test

**Files:**
- No edits.

- [ ] **Step 1: Clean everything**

```bash
scripts/clean.sh
rm -rf dist .build-release
```

- [ ] **Step 2: Run the full distribute pipeline from a clean state**

Run: `scripts/distribute.sh 2>&1 | tee /tmp/distribute.log | tail -20`
Expected: ends with `Release artifacts:` showing both `.dmg` and `.dmg.sha256`. `/tmp/distribute.log` contains no `error:`, `FAIL`, or `** TEST FAILED **`.

- [ ] **Step 3: Mount the produced DMG and install on a clean path**

```bash
hdiutil attach -nobrowse dist/NotchShelf-1.0.0.dmg
killall NotchShelf 2>/dev/null || true
rm -rf /Applications/NotchShelf.app
cp -R /Volumes/NotchShelf*/NotchShelf.app /Applications/
hdiutil detach /Volumes/NotchShelf* | cat
xattr -dr com.apple.quarantine /Applications/NotchShelf.app
open /Applications/NotchShelf.app
sleep 2
pgrep -x NotchShelf >/dev/null && echo "OK: launched from DMG → /Applications"
```

Expected: `OK: launched from DMG → /Applications`. Smoke-test the shelf interaction once more, then `killall NotchShelf`.

- [ ] **Step 4: Verify checksum verification path works for end users**

```bash
(cd dist && shasum -a 256 -c NotchShelf-1.0.0.dmg.sha256)
```

Expected: `NotchShelf-1.0.0.dmg: OK`. (This is the exact command users will run from `INSTALL.md`.)

- [ ] **Step 5: Final status review**

```bash
git status
git log --oneline -20
```

Expected: working tree clean (no uncommitted production changes; `dist/` is gitignored). Recent commits cover Phases 1–3.

- [ ] **Step 6: Tag the release**

```bash
git tag -a v1.0.0 -m "NotchShelf 1.0.0 — initial distribution-ready release (ad-hoc signed)"
```

Do **not** push the tag automatically; let the user decide when to push.

---

## Done When

- `LICENSE`, `PRIVACY.md`, `CHANGELOG.md`, `INSTALL.md`, and the rewritten `README.md` exist and render correctly on GitHub.
- Bundle identifier is `dev.conceptfab.notchshelf`; `Info.plist` copyright is ASCII (`Michal Kleniewski`); `LSRequiresNativeExecution`, `LSArchitecturePriority=[arm64]`, and `NSHighResolutionCapable` are present and match Clank's `Info.plist`.
- The About view renders the Clank-aligned layout (Version / Author → `conceptfab.com` / Website → `notchshelf.conceptfab.com` / Icons → `MW Coffee` / Platform `Apple Silicon Mac, macOS 26+`) and a working Buy Me a Coffee button linking to `https://www.buymeacoffee.com/conceptfab`.
- **`scripts/package-dmg.sh` and `scripts/distribute.sh` are committed, executable, and remain as the permanent way to build the final DMG.** Running `scripts/distribute.sh` from a clean checkout produces a working `dist/NotchShelf-<version>.dmg` + `.sha256`. The DMG contents match Clank's layout: `.app` + `INSTALL.md` + `LICENSE` + `/Applications` symlink.
- `scripts/test.sh` reports both shell contracts green and `** TEST SUCCEEDED **` for the Swift suite (135 tests: 121 baseline + 2 `BundleResourceTests` + 9 `InfoPlistMetadataTests` + 3 `AboutViewContentTests`).
- The installed `/Applications/NotchShelf.app` launches, shows correct About metadata, and the **View License** button opens the bundled `LICENSE.txt`.
- Local git tag `v1.0.0` exists (unpushed).

## Out of Scope (Next Steps After Developer ID Purchase)

When the Apple Developer Program membership lands, follow up with:

1. Switch `project.yml` `CODE_SIGN_IDENTITY` from `"-"` to `"Developer ID Application: <name> (<team>)"`. Apply the **same** identity to NotchShelf and Clank so both apps verify as one developer.
2. Add a notarization step to `scripts/release.sh` (`xcrun notarytool submit --wait`) and stapling (`xcrun stapler staple`). Mirror the change in Clank's `Makefile`.
3. Drop the quarantine workaround section from `INSTALL.md` (keep the Gatekeeper "Open Anyway" fallback).
4. Add Sparkle EdDSA-signed auto-updates (consider a shared appcast or one per app on `*.conceptfab.com`).
5. Remove the "ad-hoc signed" note from `CHANGELOG.md` known-limitations.
6. Optional: introduce a `Localization.swift` matching Clank's bilingual EN/PL helpers and translate user-facing strings.

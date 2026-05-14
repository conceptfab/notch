# NotchShelf — MVP Design

**Date:** 2026-05-14
**Status:** Approved (brainstorming complete, ready for implementation plan)

## 1. Overview

NotchShelf is a native macOS app inspired by [Dropover](https://dropoverapp.com). You
drag selected files toward the MacBook notch, a shelf slides out from underneath it,
you drop the files there as a staging area, and later you pull them back out and drop
them into another folder.

It is built fresh as a standalone app, **porting the file-shelf component** from
[boring.notch](https://github.com/TheBoredTeam/boring.notch) (kept on disk at
`boring.notch-main/` as reference). boring.notch's shelf is feature-rich but only
lightly coupled to the rest of that app (4 `BoringViewModel` properties + 2 `Defaults`
keys), which makes the port low-risk.

## 2. MVP Scope

**In scope:**
- Drag files toward the notch → shelf slides out as a drop target.
- Drop files/folders onto the shelf (reference-only — see §8).
- Shelf persists across app/Mac restart.
- Pull items back out by dragging them into Finder (single or multi-select).
- Re-open the shelf by hovering over the notch.
- Remove items from the shelf (file on disk is untouched).

**Explicitly out of scope (MVP):**
- Image processing (background removal, format conversion, PDF creation).
- ZIP compression.
- QuickShare / AirDrop / share sheet integration.
- QuickLook preview panel (double-click opens the file in its default app instead).
- Text and link items on the shelf — files/folders only.
- Macs without a physical notch; virtual-notch fallback.
- Multi-monitor — only the built-in screen with the notch.
- Multiple shelves / stacks (Dropover has these).
- Preferences UI window.
- Notarization, distribution, auto-update.

## 3. Decisions Log

These came out of brainstorming and drive the design:

| Decision | Choice |
|----------|--------|
| Build strategy | Fresh `NotchShelf` app + port the Shelf component from boring.notch |
| Shelf trigger | Shelf slides out when files are dragged **toward the notch** |
| Notch support | Notch Macs only (built-in screen) |
| Item types | Files and folders only |
| File handling | Reference to original via security-scoped bookmark — nothing is copied |
| Persistence | Shelf survives app/Mac restart |
| Shelf shape | Continuous "Dynamic Island" shape — the notch grows down into the shelf |
| Re-open trigger | Hover over the notch |

## 4. Architecture

### 4.1 App shape

Native macOS app, Swift, SwiftUI + AppKit. Runs as `LSUIElement = true` (agent app —
no Dock icon). A menu bar icon provides quit/about only; it is **not** a primary way to
open the shelf.

One borderless `NSPanel` pinned to the top-center of the built-in (notch) screen. The
panel has two size states:
- **Collapsed** — sized to the physical notch region; fully transparent. Acts purely
  as a hover / drag hit-target.
- **Expanded** — grown downward into the shelf panel.

### 4.2 Project structure

```
NotchShelf/
  App/          NotchShelfApp.swift, AppDelegate.swift, MenuBarController.swift
  Window/       NotchPanel.swift, NotchWindowController.swift, NotchGeometry.swift
  DragDetect/   DragMonitor.swift          (global NSEvent monitor + drag pasteboard)
  Shelf/        ← ported from boring.notch
    Models/     Bookmark.swift, ShelfItem.swift
    State/      ShelfStore.swift, ShelfSelection.swift, ShelfItemViewModel.swift
    Services/   ShelfDropService.swift, ShelfPersistenceService.swift,
                ShelfActionService.swift, ThumbnailService.swift
    Views/      ShelfView.swift, ShelfItemView.swift, DragPreviewView.swift
  Shared/       ShelfWindowModel.swift, Preferences.swift
NotchShelfTests/  (Swift Testing target)
scripts/        build.sh
```

### 4.3 The notch window

- `NotchPanel` — borderless `NSPanel` subclass. Properties mirror boring.notch's
  proven config: `level = .mainMenu + 3`, `collectionBehavior = [.fullScreenAuxiliary,
  .stationary, .canJoinAllSpaces, .ignoresCycle]`, `isFloatingPanel = true`,
  `isOpaque = false`, `backgroundColor = .clear`, `isMovable = false`,
  `hasShadow = false`, `canBecomeKey = false`, `canBecomeMain = false`,
  `isReleasedWhenClosed = false`.
- `NotchGeometry` — detects the notch rectangle from `NSScreen.safeAreaInsets` /
  `NSScreen.auxiliaryTopLeftArea`. Provides notch width/height and the screen-space
  hit-region used by drag detection and hover.
- `NotchWindowController` — positions the panel at top-center of the notch screen,
  drives the resize animation between collapsed and expanded sizes.
- The panel hosts an `NSHostingView` whose root view observes `ShelfWindowModel`.
  Collapsed → renders effectively nothing (transparent). Expanded → renders the
  continuous notch-into-shelf shape (decision: shape A) with the shelf content below.

### 4.4 Drag detection

- `DragMonitor` — installs a global event monitor
  (`NSEvent.addGlobalMonitorForEvents` for `.leftMouseDragged` / `.leftMouseUp`) and
  inspects `NSPasteboard(name: .drag)` for `.fileURL` content to confirm a file drag
  is in progress. (Global *mouse* monitoring works inside the App Sandbox without
  Accessibility permission — boring.notch's `DragDetector` does exactly this.)
- When a confirmed file drag enters the `NotchGeometry` hit-region, it sets
  `ShelfWindowModel.dragTargeting = true` and triggers expansion.

### 4.5 Decoupling from boring.notch

The ported Shelf code references the host app in only two ways. Both get small local
replacements:

- **`ShelfWindowModel`** — `ObservableObject`, injected as `@EnvironmentObject`.
  Replaces the 4 `BoringViewModel` touch-points: `dragTargeting`, `dropEvent`,
  `animation`, plus an `expansion` state (`.collapsed` / `.expanded`) that drives the
  window resize. (`dropZoneTargeting` is dropped — it belonged to `FileShareView`,
  which is out of scope.)
- **`Preferences`** — a thin wrapper over plain `UserDefaults` for the two keys the
  shelf actually uses: `copyOnDrag` (default `false`) and `autoRemoveShelfItems`
  (default `false`). The `Defaults` SPM dependency is dropped entirely.

## 5. The Shelf (ported component)

### 5.1 Data model

- **`ShelfItem`** — simplified from boring.notch. The original `ShelfItemKind` enum
  (file/text/link) collapses to a plain struct holding a file bookmark, since the MVP
  is files-only: `id: UUID`, `bookmarkData: Data`, plus computed `displayName` (from
  the resolved URL), `fileURL`, and `icon`. The TextBlock/WebLoc special-case naming
  logic is dropped.
- **`Bookmark`** — ported essentially 1:1 (no external dependencies). Security-scoped
  bookmark wrapper: create from URL, `resolve()` with staleness detection,
  `validate()`, `withAccess()` for scoped resource access.

### 5.2 State

- **`ShelfStore`** (boring.notch's `ShelfStateViewModel`) — `@Published items:
  [ShelfItem]`; `add()` with dedup by standardized file path; `load(providers:)`
  async; `resolveFileURL()` that refreshes stale bookmarks; `cleanupInvalidItems()`
  that prunes dead entries on launch. Saves on every `items` change.
- **`ShelfSelection`** — `@Published selectedIDs: Set<UUID>` and `isDragging`;
  single / toggle / shift-range selection. Ported nearly 1:1.
- **`ShelfItemViewModel`** — heavily trimmed from 1112 → ~200 lines. Keeps: thumbnail
  loading, `dragItemProvider()` (drag-out, multi-select aware), click handling
  (select / toggle / shift), double-click → open, and a **minimal context menu**
  (Open, Show in Finder, Remove — ~30 lines). Drops: image processing, ZIP
  compression, the "Open With" panel, rename dialog — roughly 900 lines.

### 5.3 Services

- **`ShelfDropService`** — `items(from: [NSItemProvider]) async -> [ShelfItem]`,
  files-only (the text/url/data branches are removed). Creates bookmarks from resolved
  file URLs.
- **`ShelfPersistenceService`** — JSON at
  `~/Library/Application Support/NotchShelf/shelf.json`. Load + `cleanupInvalidItems()`
  on launch; save on every `items` change. Corrupted individual entries are skipped
  with a warning rather than failing the whole load.
- **`ShelfActionService`** — `open` (NSWorkspace), `reveal` (Show in Finder),
  `copyPath`, `remove`.
- **`ThumbnailService`** — kept. Actor-based cache around `QLThumbnailGenerator`, no
  external dependencies. Without thumbnails the shelf is barely usable, so this is in
  MVP scope despite being "nice-to-have" in the source app.

### 5.4 Views

- **`ShelfView`** — the shelf container: a horizontally scrolling row of item cards,
  or a "Drop files here" hint when empty. Drop target wiring goes through
  `ShelfWindowModel` instead of `BoringViewModel`.
- **`ShelfItemView`** — a single item card (thumbnail, name, selection/drop-target
  styling, drag source via `NSViewRepresentable`).
- **`DragPreviewView`** — the small view rendered under the cursor during drag-out.

## 6. Interactions

**Drop in (add files):**
1. Select files in Finder, start dragging.
2. `DragMonitor` detects a file drag.
3. Cursor enters the notch hit-region → `ShelfWindowModel.expansion = .expanded`,
   window animates open, shelf appears as a drop target.
4. Drop → `ShelfStore.load(providers)` creates bookmarks, adds items (deduped by path).
5. The shelf stays open after the drop; it collapses on click-outside, `Esc`, or when
   the cursor leaves the region for ~1.5 s.

**Re-open (retrieve later):** hover over the notch (with a small delay) expands the
shelf. If empty, it shows the "Drop files here" hint.

**Drag out (move to a folder):** grab an item (or the whole current selection) and
drag into a Finder folder. `dragItemProvider()` builds an `NSItemProvider` from the
file URL (after `resolveAndUpdateBookmark`). Default operation is `copy | move` — Finder
decides (same volume = move, cross-volume = copy; ⌘/⌥ modifiers as usual). If
`autoRemoveShelfItems` is on, a successful drag-out removes the item from the shelf.

**Multi-select:** click = select one, ⌘+click = toggle, ⇧+click = range. Dragging a
selected item drags the whole selection.

**Remove:** context-menu *Remove* or the `Delete` key removes from the shelf. The file
on disk is untouched — the shelf only holds a reference.

## 7. Window states & animation

Three lifecycle states, all driven by `ShelfWindowModel`:
1. **Idle / collapsed** — transparent strip over the notch.
2. **Drag-targeting** — notch highlights and begins growing as a file drag enters its
   region.
3. **Expanded** — full shelf.

Shape: **continuous (decision A)** — the notch grows downward into a single organic
"Dynamic Island"-style shape, with the shelf content as its lower extension. This is
more native-feeling but carries the most geometry/animation work in the project; the
mask shape and the collapse↔expand animation are the main implementation risk (see
§12).

## 8. Persistence & file references

The shelf stores **references**, not copies. Each `ShelfItem` holds a security-scoped
bookmark to the original file in its original location. Consequences:
- The shelf is lightweight; nothing is duplicated on disk.
- Bookmarks survive app/Mac restart (this is the whole point of the entitlements).
- Stale bookmarks are refreshed on resolve; bookmarks that no longer resolve are
  pruned by `cleanupInvalidItems()` on launch.
- Known limitation: if the original file is deleted or moved somewhere the bookmark
  cannot follow, that shelf entry dies. Accepted for MVP (matches boring.notch's
  default behavior).

## 9. Project setup

- **Xcode project** — `NotchShelf.xcodeproj` (an app target, not a Swift Package — we
  need an app bundle, entitlements, and `Info.plist`). Deployment target: **macOS 14
  (Sonoma)**.
- **`Info.plist`** — `LSUIElement = true`.
- **Dependencies** — none. Apple frameworks only (Foundation, AppKit, SwiftUI,
  Combine, UniformTypeIdentifiers, QuickLookThumbnailing).
- **`scripts/build.sh`** — wraps `xcodebuild` to produce a runnable `.app` without
  opening Xcode, for fast iteration.

**Entitlements (only what's needed):**
- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.bookmarks.app-scope` = true
- `com.apple.security.files.bookmarks.document-scope` = true
- `com.apple.security.files.user-selected.read-write` = true

No camera, calendar, network, or Apple-events entitlements.

**Signing / distribution:** local builds, ad-hoc signing ("Sign to Run Locally") — enough
to run on the developer's own Mac. No Apple Developer account, so no notarization.
Distribution and auto-update are out of scope.

## 10. Testing strategy

Framework: **Swift Testing**.

Unit-tested:
- `Bookmark` — create / resolve / validate round-trip against real temporary files.
- `ShelfStore` — add / dedup, `cleanupInvalidItems`, persistence round-trip.
- `ShelfSelection` — single / toggle / shift-range logic (pure).
- `ShelfPersistenceService` — JSON save/load, corrupted-entry handling.
- `ShelfDropService` — `items(from:)` with synthetic `NSItemProvider`s.
- `NotchGeometry` — notch-rectangle math.

Verified manually / via integration: `DragMonitor`, `NotchPanel` window behavior, and
the SwiftUI views (drag-in, drag-out, hover-to-open, animation).

## 11. Out of scope

Listed in §2. Each could become its own follow-up spec → plan → implementation cycle
after the MVP is working.

## 12. Risks & notes

- **Continuous-shape animation (§7)** is the highest-risk piece — the notch-into-shelf
  mask geometry and the collapse↔expand animation. If it proves too costly during
  implementation, the fallback is the simpler "separate card" shape (brainstorming
  option B); revisit with the user rather than silently switching.
- **`ShelfItemViewModel` port** — the source file is 1112 lines and entangles the
  ~200 lines we want with ~900 lines we don't. The port should be a deliberate rewrite
  of the keep-list, not a delete-pass over the original.
- **Git** — `/Users/micz/__DEV__/notch` is not a git repository, so this design doc
  cannot be committed yet. Recommend `git init` before implementation so the plan and
  code history are tracked.
- **boring.notch as reference** — `boring.notch-main/` stays on disk purely as a
  reference to copy proven code from. It is not a dependency and not built.

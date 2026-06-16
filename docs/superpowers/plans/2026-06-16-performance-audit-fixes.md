# NotchShelf Performance Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the always-on idle CPU drain, stop redundant disk writes, remove dead code, and cut main-thread work in the shelf render/drag hot paths — without changing user-visible behavior.

**Architecture:** Two phases. **Phase 1** is unit-test-driven (TDD): gate the notification-window poll behind the existing preference, guard persistence against no-op writes, and delete confirmed dead code. **Phase 2** is rendering/I-O work that cannot be meaningfully unit-tested (SwiftUI visual + NSWorkspace I/O); each task ships with explicit run-the-app verification steps.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Swift Testing (`import Testing`, `@Test`), xcodegen + xcodebuild. macOS 26 target.

**Build/test commands (whole suite — single-test filtering is unreliable with free `@Test` functions):**
- Build: `bash scripts/build.sh`
- Test: `bash scripts/test.sh`
- Run the app: `bash scripts/run.sh`

---

## File Structure

Phase 1 (testable):
- Modify: `NotchShelf/App/SystemEventGlowCoordinator.swift` — gate the window monitor on `glowOnSystemEvents`; expose test seams.
- Test: `NotchShelfTests/SystemEventGlowCoordinatorTests.swift` — add gating tests (file already exists).
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift` — equality guard in `slots` `didSet`; add `scheduledSaveCount` test hook.
- Test: `NotchShelfTests/ShelfStoreTests.swift` — add no-op-write tests.
- Modify: `NotchShelf/Window/ShelfMetrics.swift` — delete dead members.
- Modify: `NotchShelf/App/SystemNotificationWindowMonitor.swift`, `NotchShelf/Shelf/State/ShelfItemViewModel.swift` — drop redundant imports.

Phase 2 (manual verification):
- Modify: `NotchShelf/App/ContentView.swift` — conditional-mount the startup glow.
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift` + `NotchShelf/Shelf/State/ShelfItemViewData.swift` — move bookmark/icon resolution off the main thread; add a shared icon cache.
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift` — render the drag preview lazily.
- Modify: `NotchShelf/App/AppDelegate.swift` + `NotchShelf/DragDetect/DragMonitor.swift` — cache notch geometry.

---

# Phase 1 — Testable fixes (do these first)

## Task 1: Gate the notification-window poll on `glowOnSystemEvents`

**Why:** `SystemNotificationWindowMonitor` runs a 0.35s `Timer` that calls `CGWindowListCopyWindowInfo` (scans every on-screen window) forever — even when the glow feature is disabled and even when the shelf is hidden. This is the dominant idle CPU/battery cost. The glow is already suppressed in `triggerGlowIfEnabled` (`SystemEventGlowCoordinator.swift:115`), but the expensive poll still runs. Only run the monitor when `glowOnSystemEvents == true`.

**Files:**
- Modify: `NotchShelf/App/SystemEventGlowCoordinator.swift`
- Test: `NotchShelfTests/SystemEventGlowCoordinatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `NotchShelfTests/SystemEventGlowCoordinatorTests.swift` (keep existing imports/tests). These rely on the existing `makeTestUserDefaults()` helper in `NotchShelfTests/TestSupport.swift`:

```swift
@MainActor @Test func glowCoordinatorDoesNotMonitorWindowsWhenSystemEventGlowDisabled() {
    let defaults = makeTestUserDefaults()
    defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
    let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
    coordinator.start()
    #expect(coordinator.isMonitoringNotificationWindows == false)
    coordinator.stop()
}

@MainActor @Test func glowCoordinatorMonitorsWindowsWhenSystemEventGlowEnabled() {
    let defaults = makeTestUserDefaults()
    defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
    let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
    coordinator.start()
    #expect(coordinator.isMonitoringNotificationWindows == true)
    coordinator.stop()
}

@MainActor @Test func glowCoordinatorStopsMonitoringWhenPreferenceTurnedOff() {
    let defaults = makeTestUserDefaults()
    defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
    let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
    coordinator.start()
    #expect(coordinator.isMonitoringNotificationWindows == true)

    defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
    coordinator.refreshWindowMonitor()
    #expect(coordinator.isMonitoringNotificationWindows == false)
    coordinator.stop()
}
```

> Note: `glowCoordinatorStopsMonitoringWhenPreferenceTurnedOff` calls `refreshWindowMonitor()` directly to keep the assertion deterministic (it does not depend on `UserDefaults.didChangeNotification` delivery timing). Production wires the same call to that notification in Step 3.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh`
Expected: FAIL — `value of type 'SystemEventGlowCoordinator' has no member 'isMonitoringNotificationWindows'` and `...'refreshWindowMonitor'`.

- [ ] **Step 3: Implement the gating**

In `NotchShelf/App/SystemEventGlowCoordinator.swift`, replace the monitor setup block at the end of `start()` (currently lines 85-89):

```swift
        let monitor = SystemNotificationWindowMonitor { [weak self] in
            self?.triggerGlowIfEnabled(reason: "notification-window")
        }
        monitor.start()
        systemNotificationWindowMonitor = monitor
    }
```

with:

```swift
        appEventObservers.append(
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: defaults,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshWindowMonitor() }
            }
        )

        refreshWindowMonitor()
    }

    /// Starts or stops the notification-window poll to match the
    /// `glowOnSystemEvents` preference. Idempotent. Internal for tests.
    func refreshWindowMonitor() {
        let enabled = defaults.bool(forKey: UserDefaultsKey.glowOnSystemEvents)
        if enabled, systemNotificationWindowMonitor == nil {
            let monitor = SystemNotificationWindowMonitor { [weak self] in
                self?.triggerGlowIfEnabled(reason: "notification-window")
            }
            monitor.start()
            systemNotificationWindowMonitor = monitor
        } else if !enabled, let monitor = systemNotificationWindowMonitor {
            monitor.stop()
            systemNotificationWindowMonitor = nil
        }
    }

    /// Test seam: whether the window poll is currently running.
    var isMonitoringNotificationWindows: Bool { systemNotificationWindowMonitor != nil }
```

The existing `stop()` already removes everything in `appEventObservers` via `NotificationCenter.default.removeObserver` and already calls `systemNotificationWindowMonitor?.stop()` then nils it — no change needed there.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/test.sh`
Expected: PASS — all three new tests green, existing `SystemEventGlowCoordinatorTests` still green.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/App/SystemEventGlowCoordinator.swift NotchShelfTests/SystemEventGlowCoordinatorTests.swift
git commit -m "perf: only poll notification windows when system-event glow is enabled"
```

---

## Task 2: Skip persistence saves when the slot array is unchanged

**Why:** Every assignment to `ShelfStore.slots` schedules a debounced full-store JSON re-encode + atomic disk write (`slots` `didSet` → `schedulePersistenceSave`). Several flows (`cleanupInvalidItems`, `clearAll` on an empty shelf, re-setting an already-current keep flag) assign a structurally identical array and still schedule a write. `ShelfSlot`/`ShelfItem` are already `Equatable`, so a cheap guard removes the redundant disk I/O.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Test: `NotchShelfTests/ShelfStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `NotchShelfTests/ShelfStoreTests.swift` (reuses the file's existing `storeWithTempPersistence()` and `makeFileItem(named:)` helpers):

```swift
@MainActor @Test func addSchedulesExactlyOneSave() throws {
    let store = storeWithTempPersistence()
    let before = store.scheduledSaveCount
    let a = try makeFileItem(named: "a.txt")
    store.add([a])
    #expect(store.scheduledSaveCount == before + 1)
}

@MainActor @Test func clearAllOnEmptyShelfSchedulesNoSave() {
    let store = storeWithTempPersistence()
    let before = store.scheduledSaveCount
    store.clearAll()
    #expect(store.scheduledSaveCount == before)
}

@MainActor @Test func redundantKeepFlagWriteSchedulesNoSave() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem(named: "a.txt")
    store.add([a])
    let slotID = store.slots.first { $0.item != nil }!.id

    store.setKeepsItemAfterExternalDrop(true, forSlotID: slotID) // real change
    let afterFirst = store.scheduledSaveCount
    store.setKeepsItemAfterExternalDrop(true, forSlotID: slotID) // no-op
    #expect(store.scheduledSaveCount == afterFirst)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh`
Expected: FAIL — `value of type 'ShelfStore' has no member 'scheduledSaveCount'`.

- [ ] **Step 3: Add the equality guard and the test hook**

In `NotchShelf/Shelf/State/ShelfStore.swift`, change the `slots` declaration (currently lines 34-36):

```swift
    @Published private(set) var slots: [ShelfSlot] = [] {
        didSet { schedulePersistenceSave() }
    }
```

to:

```swift
    @Published private(set) var slots: [ShelfSlot] = [] {
        didSet {
            guard slots != oldValue else { return }
            schedulePersistenceSave()
        }
    }

    /// Test hook: number of times a debounced persistence save was scheduled.
    private(set) var scheduledSaveCount = 0
```

Then in `schedulePersistenceSave()` (currently line 289), increment the counter on the first line of the method body:

```swift
    private func schedulePersistenceSave() {
        scheduledSaveCount += 1
        saveTask?.cancel()
```

(leave the rest of `schedulePersistenceSave` unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/test.sh`
Expected: PASS — the three new tests green and the existing `ShelfStoreTests` suite still green (the guard does not change observable state, only suppresses no-op writes).

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/ShelfStoreTests.swift
git commit -m "perf: skip shelf persistence save when slot array is unchanged"
```

---

## Task 3: Delete confirmed dead code and redundant imports

**Why:** `ShelfMetrics.maximumVisibleSlotCount(baseSlotCount:additionalRows:)` and `ShelfMetrics.itemBodyHeight` have zero references anywhere in the repo (capacity is computed via `SlotCountPolicy.visibleSlotCount`). Two imports are redundant because `AppKit`/`SwiftUI` re-export them.

**Files:**
- Modify: `NotchShelf/Window/ShelfMetrics.swift`
- Modify: `NotchShelf/App/SystemNotificationWindowMonitor.swift`
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`

- [ ] **Step 1: Verify the symbols are truly unreferenced**

Run:
```bash
rg -n 'maximumVisibleSlotCount|itemBodyHeight' NotchShelf NotchShelfTests
```
Expected: matches ONLY at the declarations in `NotchShelf/Window/ShelfMetrics.swift` (line ~66 and ~116). If any other file references them, STOP and do not delete — re-scope this task.

- [ ] **Step 2: Delete `itemBodyHeight`**

In `NotchShelf/Window/ShelfMetrics.swift`, delete this line (currently line 66):

```swift
    static let itemBodyHeight: CGFloat = itemHeight - itemToggleHeight - 2
```

- [ ] **Step 3: Delete `maximumVisibleSlotCount`**

In `NotchShelf/Window/ShelfMetrics.swift`, delete this method (currently lines 116-119):

```swift
    static func maximumVisibleSlotCount(baseSlotCount: Int, additionalRows: Int) -> Int {
        normalizedSlotCount(baseSlotCount)
            * (1 + normalizedAdditionalRowCount(additionalRows, baseSlotCount: baseSlotCount))
    }
```

- [ ] **Step 4: Drop the redundant `import CoreGraphics`**

In `NotchShelf/App/SystemNotificationWindowMonitor.swift`, delete line 2:

```swift
import CoreGraphics
```

(The file keeps `import AppKit`, which re-exports CoreGraphics and the `CGWindowID`/`CGWindowList*` symbols.)

- [ ] **Step 5: Drop the redundant `import Foundation`**

In `NotchShelf/Shelf/State/ShelfItemViewModel.swift`, delete line 2:

```swift
import Foundation
```

(The file keeps `import AppKit` and `import SwiftUI`, both of which re-export Foundation; `import ObjectiveC` stays — it is needed for `objc_setAssociatedObject`.)

- [ ] **Step 6: Build and test to verify nothing broke**

Run: `bash scripts/test.sh`
Expected: PASS — full build succeeds with no "use of unresolved identifier" errors and the whole suite is green.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf/Window/ShelfMetrics.swift NotchShelf/App/SystemNotificationWindowMonitor.swift NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "chore: remove dead ShelfMetrics members and redundant imports"
```

> **Out of scope (deliberately not deleted):** `ShelfStore.resolveFileURL(for:)`, `ShelfStore.flushPendingSave()`, `ThumbnailService.clearCache()`, the 1-arg `ShelfDragOperationPolicy.shouldRemoveFromShelf(after:)` overload, and `NotchGeometry.hasNotch` are referenced only by tests. They are intentional test seams; removing them means deleting their tests too. Leave them unless the owner decides otherwise.

---

# Phase 2 — Rendering & I-O optimizations (manual verification)

These change SwiftUI rendering and NSWorkspace/bookmark I/O. They are verified by running the app and observing behavior + CPU, not by unit tests. Do them one at a time and re-verify after each.

## Task 4: Conditional-mount the startup glow so it leaves the reveal animation

**Why:** `StartupGlowView` is always mounted in `ContentView`'s ZStack (only its `.opacity` is toggled). Its corner radii are driven by `currentTopCornerRadius` and the expanded/collapsed branch, both tied to `windowModel.expansion`, which is animated by `.animation(shelfAnimation, value:)`. So `NotchShelfGlowEdgesShape.animatableData` interpolates three blurred gradient strokes on every frame of every shelf reveal/collapse — even while the glow opacity is 0. The glow only needs to draw for the ~1.2s launch accent.

**Files:**
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Gate the glow on `isStartupGlowVisible` and detach it from the animated corner radius**

In `NotchShelf/App/ContentView.swift`, replace the `StartupGlowView` block at the top of the `body` ZStack (currently lines 128-137):

```swift
            StartupGlowView(
                topCornerRadius: currentTopCornerRadius,
                bottomCornerRadius: windowModel.expansion == .expanded
                    ? ShelfMetrics.bottomCornerRadius : 8,
                glowColor: glowRGBA.color
            )
                .frame(width: currentShapeSize.width, height: currentShapeSize.height)
                .opacity(isStartupGlowVisible ? 1 : 0)
                .allowsHitTesting(false)
                .zIndex(20)
```

with (mount only while visible; feed static radii so the glow is not part of the shelf-shape animation transaction; rasterize the blurred strokes once):

```swift
            if isStartupGlowVisible {
                StartupGlowView(
                    topCornerRadius: ShelfMetrics.topCornerRadiusExpanded,
                    bottomCornerRadius: ShelfMetrics.bottomCornerRadius,
                    glowColor: glowRGBA.color
                )
                    .frame(width: currentShapeSize.width, height: currentShapeSize.height)
                    .compositingGroup()
                    .drawingGroup()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(20)
            }
```

- [ ] **Step 2: Build, run, and verify the glow still appears at launch**

Run: `bash scripts/run.sh`
Expected behavior:
- On launch, the colored glow pulses once around the notch outline (fade in, hold, fade out over ~1.2s), visually unchanged from before.
- Opening/closing the shelf no longer redraws the glow (it is unmounted once `isStartupGlowVisible` is false).
- No regression in the shelf reveal/collapse animation smoothness.

If the glow's static radii look visibly different from before, adjust the `bottomCornerRadius` argument to match the collapsed value (`8`) — choose whichever matches the launch state on this machine (the shelf is collapsed at launch, so `8` may be the correct bottom radius). Pick the value that reproduces the original look and note it in the commit message.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/ContentView.swift
git commit -m "perf: mount startup glow only while visible and rasterize its strokes"
```

## Task 5: Move per-item bookmark + icon resolution off the main thread, with an icon cache

**Why:** `ShelfItemViewModel.update(item:)` synchronously runs `ShelfItemViewData.build` (resolves a security-scoped bookmark + `url.resourceValues` disk read) and `Self.icon(for:)` (`NSWorkspace.shared.icon(forFile:)`) on the main actor, on every genuine `item` change. Dropping N files or re-slotting fires this N times on the UI thread, causing a hitch right as the shelf animates open.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`
- Modify: `NotchShelf/Shelf/State/ShelfItemViewData.swift` (only if you extract resolution; see Step 1)

- [ ] **Step 1: Add a shared, size-bounded icon cache keyed by resolved path**

In `NotchShelf/Shelf/State/ShelfItemViewModel.swift`, add near the top of the file (after imports):

```swift
/// Process-wide cache of file icons keyed by resolved path. Avoids repeated
/// synchronous NSWorkspace lookups when items re-slot or re-render.
@MainActor
private enum ShelfIconCache {
    private static var entries: [String: NSImage] = [:]
    private static var order: [String] = []
    private static let limit = 128

    static func icon(forPath path: String) -> NSImage? { entries[path] }

    static func store(_ image: NSImage, forPath path: String) {
        if entries[path] == nil {
            order.append(path)
            if order.count > limit {
                let evicted = order.removeFirst()
                entries[evicted] = nil
            }
        }
        entries[path] = image
    }
}
```

- [ ] **Step 2: Make `update(item:)` resolve off-main and publish back on the main actor**

In `NotchShelf/Shelf/State/ShelfItemViewModel.swift`, replace `update(item:)` (currently lines 33-38):

```swift
    func update(item: ShelfItem) {
        guard self.item != item else { return }
        self.item = item
        self.viewData = ShelfItemViewData.build(from: item)
        self.icon = Self.icon(for: item)
    }
```

with:

```swift
    func update(item: ShelfItem) {
        guard self.item != item else { return }
        self.item = item

        // Serve a cached icon immediately if we have one for the current path.
        if let path = item.fileURL?.path, let cached = ShelfIconCache.icon(forPath: path) {
            self.icon = cached
        }

        // Resolve display name + icon off the main thread; publish back on main.
        let snapshot = item
        Task.detached(priority: .userInitiated) {
            let data = ShelfItemViewData.build(from: snapshot)
            let resolvedPath = snapshot.fileURL?.path
            let image = await Self.resolveIcon(for: snapshot)
            await MainActor.run {
                guard self.item == snapshot else { return } // a newer update won
                self.viewData = data
                self.icon = image
                if let resolvedPath { ShelfIconCache.store(image, forPath: resolvedPath) }
            }
        }
    }

    /// Off-main icon resolution. Mirrors `icon(for:)` but is callable from a detached task.
    private nonisolated static func resolveIcon(for item: ShelfItem) async -> NSImage {
        if let url = item.fileURL {
            return url.accessSecurityScopedResource {
                NSWorkspace.shared.icon(forFile: $0.path)
            }
        }
        return NSWorkspace.shared.icon(for: .data)
    }
```

> The synchronous initializer path (`init`) is left as-is so the first frame still has an icon; only the per-change `update` is moved off-main. `ShelfItemViewData` and `ShelfItem` are `Sendable`, so capturing `snapshot` across the actor boundary is safe.

- [ ] **Step 3: Build and verify icons + names still appear and update correctly**

Run: `bash scripts/run.sh`
Expected behavior:
- Drop several files at once: icons and names populate (within a frame or two), no UI freeze during the drop animation.
- Re-slot an item (drag within the shelf): its icon/name stay correct.
- Remove a file from a stack: the remaining item's name (`"folder (N)"`) updates.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "perf: resolve shelf item icon/name off the main thread with an icon cache"
```

## Task 6: Render the drag preview lazily instead of eagerly per slot

**Why:** `ShelfItemView` calls `refreshDragPreview()` from both `onAppear` and `onChange(of: item)`. That spins up an `ImageRenderer` and rasterizes an `NSImage` for every slot at load and on every item change, but the rendered image is only consumed when a drag actually begins.

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Inspect the current drag-preview wiring**

Run:
```bash
rg -n 'refreshDragPreview|ImageRenderer|dragPreview' NotchShelf/Shelf/Views/ShelfItemView.swift
```
Read the `refreshDragPreview()` body and the `onAppear` / `onChange(of: item)` call sites, and find where the rendered preview is consumed at drag start (the AppKit click/drag handler).

- [ ] **Step 2: Remove the eager calls and render on demand**

- Delete the `refreshDragPreview()` calls in `onAppear` and `onChange(of: item)`.
- Move the `ImageRenderer` rasterization to the point where the drag session starts (the `mouseDragged` / `startDragSession` path). If the drag start already has access to `viewModel.icon` as a fallback, render the rich preview there once; otherwise call `refreshDragPreview()` at the top of the drag-start handler before constructing the dragging item.
- Keep the rendered image cached in the existing stored property so a single drag does not re-render mid-gesture; invalidate it in `onChange(of: viewModel.icon)` only (not on every `item` change).

- [ ] **Step 3: Build and verify dragging still shows the correct preview**

Run: `bash scripts/run.sh`
Expected behavior:
- Dragging an item OUT of the shelf shows the same rich drag preview as before.
- Dragging a multi-selection shows the correct multi-item preview.
- No visible difference at rest; load with many items no longer rasterizes previews up front (verify with Instruments Time Profiler if available, or by confirming no per-slot render work on appear).

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "perf: render shelf drag preview lazily at drag start"
```

## Task 7: Cache notch geometry instead of recomputing per drag event

**Why:** `DragMonitor`'s region provider (`AppDelegate.swift:40-47`) calls `NotchGeometry.current()` — which enumerates `NSScreen.screens` — on every `leftMouseDragged` event while a file drag is active. Geometry only changes when the screen configuration changes.

**Files:**
- Modify: `NotchShelf/App/AppDelegate.swift`

- [ ] **Step 1: Cache `NotchGeometry.current()` and invalidate on screen-parameter changes**

In `NotchShelf/App/AppDelegate.swift`:
- Add a stored property `private var cachedGeometry: NotchGeometry?`.
- Add a `private func notchGeometry() -> NotchGeometry { if let cachedGeometry { return cachedGeometry }; let g = NotchGeometry.current(); cachedGeometry = g; return g }`.
- In `setupDragMonitor()`'s `regionProvider` closure, replace both `NotchGeometry.current()` calls with `self.notchGeometry()`.
- In `applicationDidFinishLaunching`, register for `NSApplication.didChangeScreenParametersNotification` and set `cachedGeometry = nil` on fire (the glow coordinator already observes this notification for its own purpose — add a separate observer here, or invalidate the cache from a shared place). Remove the observer in `applicationWillTerminate`.

- [ ] **Step 2: Build and verify drag-to-open still works on the correct screen**

Run: `bash scripts/run.sh`
Expected behavior:
- Dragging a file toward the notch still opens the shelf (collapsed → expanded) with the same catch region.
- After changing display arrangement / resolution / plugging in an external display, the catch region recomputes correctly (drag-to-open still works on the active notch screen).

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/AppDelegate.swift
git commit -m "perf: cache notch geometry and invalidate on screen-parameter changes"
```

---

## Self-Review

**Spec coverage (audit findings → tasks):**
- Idle CPU poll (audit #1) → Task 1.
- Redundant persistence writes (audit #5) → Task 2.
- Dead code: `maximumVisibleSlotCount`, `itemBodyHeight`, redundant imports → Task 3.
- Glow re-tessellation (audit #3) → Task 4.
- Main-thread bookmark+icon I/O (audit #2) → Task 5.
- Eager `ImageRenderer` drag preview (audit #4) → Task 6.
- `NotchGeometry.current()` per drag event (audit medium) → Task 7.
- Deliberately deferred (lower value / higher risk, noted not silently dropped): ShelfStore `items`/`totalFileCount`/`visibleSlotCount` memoization; stack-panel icon/bookmark resolution off-main (Task 5's icon cache is reusable here); `ThumbnailService` `backingScaleFactor` main-actor hop; broad `UserDefaults.didChangeNotification` subscriptions in `ContentView`/`ShelfView`; `gridColumns` per-render allocation. Run a follow-up plan for these once Phase 1 + Phase 2 land.

**Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" — Task 6's drag-start edit is described structurally because the exact handler lines must be read at execution time (Step 1 locates them); all other code steps show full code.

**Type consistency:** `refreshWindowMonitor()` / `isMonitoringNotificationWindows` (Task 1), `scheduledSaveCount` (Task 2), `ShelfIconCache.icon(forPath:)` / `store(_:forPath:)` / `resolveIcon(for:)` (Task 5) are each defined once and referenced with matching signatures. `UserDefaultsKey.glowOnSystemEvents`, `ShelfMetrics.topCornerRadiusExpanded`, `ShelfMetrics.bottomCornerRadius`, `makeTestUserDefaults()`, `storeWithTempPersistence()`, `makeFileItem(named:)` all exist in the current codebase.

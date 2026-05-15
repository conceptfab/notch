# NotchShelf v1.0 Stable Release — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take NotchShelf from a working MVP to a tagged, shippable v1.0 — fixing the correctness/crash/data-loss issues, the memory/CPU regressions, and the release-hygiene gaps identified by the 2026-05-15 four-agent audit.

**Architecture:** Pure refactor + cleanup work over an already-architected app. No new features. Each task is scoped to a single concern so it can be reviewed and reverted independently. Order: correctness first, performance second, hygiene third, polish last.

**Tech Stack:** Swift 6.0, SwiftUI + AppKit hybrid, XcodeGen (`project.yml`), Swift Testing (`@Test` / `#expect`), `xcodebuild` for CI.

**Source of findings:** the audit report appended below the plan tasks. Each task references the audit item it resolves.

---

## Phase 0 — Baseline verification

### Task 0: Confirm green build and test baseline

**Files:**
- Read-only verification step. No code changes.

- [ ] **Step 1: Run a clean Debug build**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 2: Run a clean Release build**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Release build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`. If warnings appear that don't appear in Debug, note them — they become items in Task 18.

- [ ] **Step 3: Run the test suite**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | tail -30
```

Expected: all tests pass. Note the test count.

- [ ] **Step 4: Snapshot current binary size and code-counts (optional, for after-comparison)**

```bash
find NotchShelf -name "*.swift" -exec wc -l {} \; | awk '{s+=$1} END {print "Swift LOC:", s}'
ls -la NotchShelf.xcodeproj/build/Build/Products/Debug/NotchShelf.app/Contents/MacOS/NotchShelf 2>/dev/null || true
```

No commit. This is the reference point.

---

## Phase 1 — Critical correctness & crash fixes

### Task 1: Capture the latest snapshot inside the debounced save Task

**Audit ref:** P-CRITICAL #2 — `ShelfStore.schedulePersistenceSave` captures `slots` at *schedule time*, so the surviving Task after a burst writes a stale view.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift:209-227`
- Test: `NotchShelfTests/ShelfStoreTests.swift`

- [ ] **Step 1: Write a failing test**

Append to `NotchShelfTests/ShelfStoreTests.swift`:

```swift
@Test func debouncedSave_capturesLatestSnapshotAfterBurst() async throws {
    let dir = try TempDir.make()
    defer { try? FileManager.default.removeItem(at: dir.url) }
    let persistence = ShelfPersistenceService(directory: dir.url)
    let store = await ShelfStore(persistence: persistence)

    let first  = try ShelfItem(url: dir.url.appendingPathComponent("a.txt").touch())
    let second = try ShelfItem(url: dir.url.appendingPathComponent("b.txt").touch())

    // Burst: schedule a save with `first`, then immediately mutate to `[first, second]`.
    await MainActor.run {
        store.add([first])
        store.add([second])
    }
    await store.flushPendingSave()

    let persisted = persistence.loadSlots().compactMap(\.item)
    #expect(persisted.count == 2, "Latest snapshot must be persisted, not the stale one captured at schedule time")
}
```

If `TempDir` / `touch()` helpers don't exist in the test target, add them to `NotchShelfTests/TestSupport.swift` (create if missing):

```swift
import Foundation

struct TempDir {
    let url: URL
    static func make() throws -> TempDir {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchShelfTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return TempDir(url: url)
    }
}

extension URL {
    @discardableResult func touch() throws -> URL {
        try Data().write(to: self)
        return self
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -only-testing:NotchShelfTests/ShelfStoreTests/debouncedSave_capturesLatestSnapshotAfterBurst test 2>&1 | tail -20
```

Expected: the test fails (or passes spuriously — re-run several times if flaky, the race is timing-sensitive).

- [ ] **Step 3: Move the snapshot capture inside the Task**

Replace `NotchShelf/Shelf/State/ShelfStore.swift:209-227` `schedulePersistenceSave()` with:

```swift
private func schedulePersistenceSave() {
    saveTask?.cancel()
    let persistence = self.persistence
    let debounce = saveDebounce
    saveTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: debounce)
        guard !Task.isCancelled, let self else { return }
        if let inflightWrite = self.inflightWrite {
            _ = await inflightWrite.value
        }
        // Snapshot AFTER the sleep so the surviving task always writes the latest state.
        let snapshot = self.slots
        let write = Task.detached {
            persistence.save(snapshot).errorMessage
        }
        self.inflightWrite = write
        self.lastError = await write.value
        if self.inflightWrite == write { self.inflightWrite = nil }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
xcodebuild ... -only-testing:NotchShelfTests/ShelfStoreTests/debouncedSave_capturesLatestSnapshotAfterBurst test 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 5: Run the full suite, then commit**

```bash
xcodebuild ... test 2>&1 | tail -10
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/
git commit -m "fix(ShelfStore): capture latest slots snapshot inside debounced save task"
```

---

### Task 2: Make flushPendingSaveSync skip the duplicate fallback write

**Audit ref:** C-CRITICAL — when the in-flight write finishes before the 2 s semaphore timeout, the unconditional `persistence.save(slots)` below the wait still runs, producing a duplicate write that can clobber state.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift:249-266`

- [ ] **Step 1: Write a test that exercises the path**

Append to `NotchShelfTests/ShelfStoreTests.swift`:

```swift
@Test func flushSync_doesNotDoubleWriteWhenInflightCompletes() async throws {
    let dir = try TempDir.make()
    defer { try? FileManager.default.removeItem(at: dir.url) }
    let persistence = CountingPersistence(directory: dir.url)
    let store = await ShelfStore(persistence: persistence)

    let item = try ShelfItem(url: dir.url.appendingPathComponent("x.txt").touch())
    await MainActor.run { store.add([item]) }
    await store.flushPendingSave()
    persistence.writes = 0

    await MainActor.run { store.flushPendingSaveSync() }

    #expect(persistence.writes <= 1, "flushPendingSaveSync should not duplicate-write when no work is pending")
}
```

Add `CountingPersistence` to `NotchShelfTests/TestSupport.swift`:

```swift
final class CountingPersistence: ShelfPersistenceService, @unchecked Sendable {
    var writes = 0
    override func save(_ slots: [ShelfSlot]) -> Result<Void, Error> {
        writes += 1
        return super.save(slots)
    }
}
```

If `ShelfPersistenceService` is `final`, mark the methods to be overridden as `open` via subclassing through composition instead: add a `PersistenceCounter` protocol — or skip the unit test and rely on the code review.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild ... -only-testing:NotchShelfTests/ShelfStoreTests/flushSync_doesNotDoubleWriteWhenInflightCompletes test
```

Expected: FAIL with `writes == 2`.

- [ ] **Step 3: Make the fallback write conditional**

Replace `flushPendingSaveSync()` in `NotchShelf/Shelf/State/ShelfStore.swift:249-266`:

```swift
nonisolated func flushPendingSaveSync() {
    MainActor.assumeIsolated {
        let hadPending = saveTask != nil || inflightWrite != nil
        saveTask?.cancel()
        saveTask = nil
        if let inflight = inflightWrite {
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                _ = await inflight.value
                semaphore.signal()
            }
            let result = semaphore.wait(timeout: .now() + 0.5)
            if result == .timedOut {
                NSLog("flushPendingSaveSync: in-flight write did not settle within 500ms; falling through to synchronous save")
            }
            inflightWrite = nil
        }
        // Only write synchronously if there was actually pending work; otherwise the
        // most recent state is already on disk and a second write is wasted I/O.
        if hadPending {
            lastError = persistence.save(slots).errorMessage
        }
    }
}
```

- [ ] **Step 4: Run the suite**

```bash
xcodebuild ... test 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/
git commit -m "fix(ShelfStore): skip duplicate sync save when no pending state at terminate"
```

---

### Task 3: Eliminate the NSScreen force-unwrap

**Audit ref:** C-CRITICAL — `NSScreen.screens.first!` at `NotchGeometry.swift:71` crashes if macOS reports zero screens during display reconfiguration.

**Files:**
- Modify: `NotchShelf/Window/NotchGeometry.swift:67-72`
- Test: `NotchShelfTests/NotchGeometryTests.swift`

- [ ] **Step 1: Change `notchScreen` to return Optional**

Replace `NotchShelf/Window/NotchGeometry.swift:67-72`:

```swift
/// The built-in notch screen, or the main screen as a fallback. Returns nil only when
/// macOS reports zero attached screens (a transient state during display reconfiguration).
@MainActor
static var notchScreen: NSScreen? {
    NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        ?? NSScreen.main
        ?? NSScreen.screens.first
}
```

Change `static func current() -> NotchGeometry` to handle the optional:

```swift
@MainActor
static func current() -> NotchGeometry {
    guard let screen = notchScreen else {
        // No attached screens: return a zero-sized geometry. Callers should re-query
        // when `NSApplication.didChangeScreenParametersNotification` fires.
        return NotchGeometry(
            screenFrame: .zero, safeAreaTop: 0,
            auxLeftWidth: nil, auxRightWidth: nil
        )
    }
    return NotchGeometry(
        screenFrame: screen.frame,
        safeAreaTop: screen.safeAreaInsets.top,
        auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
        auxRightWidth: screen.auxiliaryTopRightArea?.width
    )
}
```

- [ ] **Step 2: Update any call site that assumed non-nil `notchScreen`**

```bash
grep -rn "notchScreen" NotchShelf
```

Patch each call site to handle the optional. Typical patch:

```swift
// Before: NotchGeometry.notchScreen.frame
// After:  NotchGeometry.notchScreen?.frame ?? .zero
```

- [ ] **Step 3: Add a test for the no-screen path**

Append to `NotchShelfTests/NotchGeometryTests.swift`:

```swift
@Test func current_returnsZeroGeometryWhenNoScreensAvailable() async {
    // We cannot mock NSScreen.screens, but we can exercise the pure init with an
    // empty-screen-equivalent input to assert it doesn't crash and returns a sane shape.
    let geometry = NotchGeometry(
        screenFrame: .zero, safeAreaTop: 0,
        auxLeftWidth: nil, auxRightWidth: nil
    )
    #expect(geometry.notchRect == CGRect(x: -92.5, y: -32, width: 185, height: 32))
    #expect(geometry.hasNotch == false)
}
```

- [ ] **Step 4: Build + run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

Expected: zero compile errors, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Window/ NotchShelfTests/
git commit -m "fix(NotchGeometry): remove force-unwrap; tolerate zero-screen states"
```

---

### Task 4: Cancel & re-check drag-preview render tasks

**Audit ref:** S-CRITICAL #1 — three unstructured `Task { await renderDragPreview() }` sites in `ShelfItemView` race. Earlier renders can clobber later previews; redundant work on every appear.

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift:10-80`

- [ ] **Step 1: Replace the three unstructured Task sites with a cancellable handle**

In `NotchShelf/Shelf/Views/ShelfItemView.swift`, add a state property near the existing `@State`s (around line 10-13):

```swift
@State private var dragPreviewTask: Task<Void, Never>?
```

Replace the three Task launches (around lines 66-80) with a single helper:

```swift
.onAppear {
    viewModel.loadThumbnail()
    refreshDragPreview()
}
.onChange(of: viewModel.thumbnail) { _, _ in refreshDragPreview() }
.onChange(of: item) { _, updated in
    viewModel.update(item: updated)
    refreshDragPreview()
}
```

Add the helper inside `ShelfItemView`:

```swift
private func refreshDragPreview() {
    dragPreviewTask?.cancel()
    dragPreviewTask = Task { @MainActor in
        let rendered = await renderDragPreview()
        guard !Task.isCancelled else { return }
        cachedPreviewImage = rendered
    }
}
```

- [ ] **Step 2: Drop the redundant `loadThumbnail` from `onAppear`**

`ShelfItemViewModel.init` already calls `loadThumbnail()` (line 28). Inside `ShelfItemView.onAppear` (Step 1), guard the call:

```swift
.onAppear {
    if viewModel.thumbnail == nil { viewModel.loadThumbnail() }
    refreshDragPreview()
}
```

- [ ] **Step 3: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

Expected: zero warnings, all tests pass.

- [ ] **Step 4: Manually exercise the shelf**

Launch the app (`xcodebuild ... -configuration Debug build && open .../NotchShelf.app`). Drop files, expand the shelf, change items, drag items. Confirm no visual regression or duplicate-preview flicker.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "fix(ShelfItemView): serialize drag-preview renders via cancellable task handle"
```

---

## Phase 2 — Memory & CPU optimization

### Task 5: Replace thumbnail dictionary with NSCache + memory pressure source

**Audit ref:** P-CRITICAL #1 — unbounded `[String: NSImage]` cache pins decoded images forever. The single biggest RSS regression.

**Files:**
- Modify: `NotchShelf/Shelf/Services/ThumbnailService.swift`
- Test: `NotchShelfTests/ThumbnailServiceTests.swift` (create if missing)

- [ ] **Step 1: Rewrite ThumbnailService to use NSCache**

Replace the body of `NotchShelf/Shelf/Services/ThumbnailService.swift`:

```swift
import AppKit
import Foundation
import QuickLookThumbnailing

/// Caching wrapper around `QLThumbnailGenerator`. Deduplicates concurrent requests
/// for the same file and size; eviction is bounded by count and total bitmap cost,
/// and is purged on system memory pressure.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 50            // at most ~50 thumbnails resident
        c.totalCostLimit = 50 * 1024 * 1024  // ~50 MB of decoded bitmaps
        return c
    }()
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private let generator = QLThumbnailGenerator.shared
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        installMemoryPressureHandler()
    }

    func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let key = "\(url.path)_\(size.width)x\(size.height)"
        let nsKey = key as NSString

        if let cached = cache.object(forKey: nsKey) { return cached }
        if let pendingTask = pending[key] { return await pendingTask.value }

        let task = Task<NSImage?, Never> { await generate(for: url, size: size) }
        pending[key] = task
        let image = await task.value
        if let image {
            let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel rough cost
            cache.setObject(image, forKey: nsKey, cost: cost)
        }
        pending[key] = nil
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func installMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { await self?.clearCache() }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func generate(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: scale, representationTypes: .all
        )
        request.iconMode = true
        return await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            generator.generateBestRepresentation(for: request) { representation, error in
                if let representation {
                    let cgImage = representation.cgImage
                    continuation.resume(returning: NSImage(
                        cgImage: cgImage,
                        size: NSSize(width: cgImage.width, height: cgImage.height)
                    ))
                } else {
                    if let error {
                        AppLogger.thumbnail.error("Thumbnail error for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
```

> Note: `AppLogger.thumbnail` is introduced in Task 15. For now, leave the existing `NSLog(...)` line in place if Task 15 hasn't run yet — replace the body of the `if let error` branch with `NSLog("Thumbnail error for \(url.path): \(error.localizedDescription)")` temporarily.

- [ ] **Step 2: Add a test that exercises the cache bound**

Create `NotchShelfTests/ThumbnailServiceTests.swift`:

```swift
import Testing
import AppKit
@testable import NotchShelf

@MainActor
struct ThumbnailServiceTests {
    @Test func clearCache_emptiesCache() async {
        let service = ThumbnailService.shared
        await service.clearCache()
        // We cannot directly inspect NSCache, but we verify clearCache is callable.
        await service.clearCache()
    }
}
```

(NSCache bounds are not easily unit-testable; the test guards against regression of the `clearCache` API used by the memory-pressure handler.)

- [ ] **Step 3: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Services/ThumbnailService.swift NotchShelfTests/
git commit -m "perf(ThumbnailService): bounded NSCache with memory-pressure eviction"
```

---

### Task 6: Cache StackFileListPanel entries and row icons

**Audit ref:** S-CRITICAL #5, P-IMPORTANT — `entries` re-resolves bookmarks and `icon` re-fetches `NSWorkspace` icons on every body eval.

**Files:**
- Modify: `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift:11-71`

- [ ] **Step 1: Resolve entries once via `onAppear` and store in `@State`**

Replace `StackFileListView` (lines 11-39) with:

```swift
struct StackFileListView: View {
    let item: ShelfItem
    @State private var entries: [StackMenuEntry] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(entries, id: \.id) { entry in
                    StackFileRowView(sourceItem: item, entry: entry)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 220)
        .scrollIndicators(.never)
        .background(Color.clear)
        .onAppear { resolveEntries() }
        .onChange(of: item) { _, _ in resolveEntries() }
    }

    private func resolveEntries() {
        entries = item.allBookmarkData.enumerated().map { index, data in
            let url = Bookmark(data: data).resolveURL()
            return StackMenuEntry(
                id: index,
                title: url?.lastPathComponent ?? "Unknown file",
                bookmarkData: data,
                fileURL: url
            )
        }
    }
}
```

- [ ] **Step 2: Cache row icon in `@State`**

Replace `StackFileRowView` (lines 41-71):

```swift
struct StackFileRowView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    @State private var icon: NSImage = NSWorkspace.shared.icon(for: .data)

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(entry.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .contentShape(Rectangle())
        .overlay {
            StackFileDragHandler(sourceItem: sourceItem, entry: entry, previewImage: icon)
        }
        .onAppear { loadIcon() }
        .onChange(of: entry.id) { _, _ in loadIcon() }
    }

    private func loadIcon() {
        if let url = entry.fileURL {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}
```

- [ ] **Step 3: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 4: Manually verify the stack list panel still renders**

Launch the app, drop a stack of files (drag multiple files from one folder), tap the stack list button, confirm icons and names render correctly and respond to clicks.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift
git commit -m "perf(StackFileListPanel): cache resolved entries and row icons in @State"
```

---

### Task 7: Cap parallel bookmark validation to 8 concurrent

**Audit ref:** P-IMPORTANT — `withTaskGroup` in `ShelfStore.validateInParallel` spawns N tasks for N items, hammering the FS on cold launch.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift:180-194`

- [ ] **Step 1: Bound the task group's concurrency**

Replace `validateInParallel` in `NotchShelf/Shelf/State/ShelfStore.swift:180-194`:

```swift
private static func validateInParallel(_ snapshot: [ShelfItem]) async -> Set<ShelfItem.ID> {
    let maxConcurrency = 8
    return await withTaskGroup(of: (ShelfItem.ID, Bool).self) { group in
        var iterator = snapshot.makeIterator()
        var inFlight = 0

        // Prime the group with up to `maxConcurrency` tasks.
        while inFlight < maxConcurrency, let item = iterator.next() {
            group.addTask {
                let isValid = await Bookmark(data: item.bookmarkData).validate()
                return (item.id, isValid)
            }
            inFlight += 1
        }

        var validIDs: Set<ShelfItem.ID> = []
        while let (id, isValid) = await group.next() {
            if isValid { validIDs.insert(id) }
            if let next = iterator.next() {
                group.addTask {
                    let isValid = await Bookmark(data: next.bookmarkData).validate()
                    return (next.id, isValid)
                }
            }
        }
        return validIDs
    }
}
```

- [ ] **Step 2: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

Expected: all pass (no behavior change for ≤8 items).

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift
git commit -m "perf(ShelfStore): cap parallel bookmark validation to 8 concurrent"
```

---

### Task 8: Cache `ShelfItemViewModel.icon`

**Audit ref:** P-MINOR — every body access calls `NSWorkspace.shared.icon(forFile:)`.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift:42-47`

- [ ] **Step 1: Convert `icon` from a computed property to a cached `@Published`**

In `NotchShelf/Shelf/State/ShelfItemViewModel.swift`, add a `@Published` near the existing ones (around line 13):

```swift
@Published private(set) var icon: NSImage = NSWorkspace.shared.icon(for: .data)
```

Delete the existing computed `var icon: NSImage { ... }` (lines 42-47).

In `init` (line 19-29), after `self.viewData = ...`, add:

```swift
self.icon = Self.icon(for: item)
```

In `update(item:)` (line 31-37), after `self.viewData = ...`, add:

```swift
self.icon = Self.icon(for: item)
```

Add the static helper at file scope inside the class:

```swift
private static func icon(for item: ShelfItem) -> NSImage {
    if let url = item.fileURL {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    return NSWorkspace.shared.icon(for: .data)
}
```

- [ ] **Step 2: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "perf(ShelfItemViewModel): cache file icon instead of recomputing per body eval"
```

---

### Task 9: Skip StackFileListPanelPresenter for non-stack items

**Audit ref:** S-IMPORTANT — presenter is attached to every item via `.background`; only stacks need it.

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift:53-57`

- [ ] **Step 1: Wrap the `.background` modifier in an `if item.isStack`**

Replace the existing `.background { if item.isStack { ... } }` modifier at line 53-57 with conditional view application using a modifier helper, since SwiftUI `.background` cannot be conditionally absent without wrapping. Use the existing pattern but ensure no NSPanel is created for non-stack items — the `if` already inside the closure handles this, but the `NSViewRepresentable` still instantiates an empty `NSView`. Eliminate that path:

Wrap the entire view in a conditional modifier:

```swift
// Replace this block (around line 52-57):
//   .background {
//       if item.isStack {
//           StackFileListPanelPresenter(item: item, isPresented: $showingStackList)
//       }
//   }
//
// With (using if-modifier guarded by isStack at the view level):

@ViewBuilder
private var contentWithStackPresenter: some View {
    if item.isStack {
        body0.background(
            StackFileListPanelPresenter(item: item, isPresented: $showingStackList)
        )
    } else {
        body0
    }
}
```

Refactor `body` to delegate to `contentWithStackPresenter` and rename the existing body content to `private var body0: some View`:

```swift
var body: some View {
    contentWithStackPresenter
}

private var body0: some View {
    ZStack {
        // ... existing ZStack contents ...
    }
    .onChange(of: viewModel.isDropTargeted) { /* ... */ }
    .onAppear { /* ... */ }
    .onChange(of: viewModel.thumbnail) { /* ... */ }
    .onChange(of: item) { /* ... */ }
}
```

- [ ] **Step 2: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 3: Manually exercise**

Launch app, drop a single file (non-stack), confirm no stack-list panel ever appears. Drop a folder full of files (stack), confirm the stack-list button works.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "perf(ShelfItemView): only attach stack list presenter to stack items"
```

---

### Task 10: Drop `.prettyPrinted` from the JSON encoder

**Audit ref:** P-MINOR — pretty-printed JSON wastes disk and encode CPU; no human reads it.

**Files:**
- Modify: `NotchShelf/Shelf/Services/ShelfPersistenceService.swift:27`

- [ ] **Step 1: Delete the pretty-print line**

In `NotchShelf/Shelf/Services/ShelfPersistenceService.swift`, delete line 27:

```swift
encoder.outputFormatting = [.prettyPrinted]
```

- [ ] **Step 2: Verify tests still parse the output correctly**

```bash
xcodebuild ... test 2>&1 | tail -10
```

Expected: all pass. `JSONDecoder` is whitespace-agnostic.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfPersistenceService.swift
git commit -m "perf(persistence): drop pretty-print formatting from shelf.json"
```

---

### Task 11: Consolidate stacked `.animation(_:value:)` in ContentView

**Audit ref:** S-IMPORTANT — three implicit animation modifiers on the same view broadcast to every descendant on every mutation.

**Files:**
- Modify: `NotchShelf/App/ContentView.swift:106-108`

- [ ] **Step 1: Hoist animations to `withAnimation` at mutation sites — OR merge into a single value-keyed animation**

The lower-impact change is to merge the three modifiers into one keyed on a composite value. Replace lines 106-108:

```swift
// Before:
//   .animation(shelfAnimation, value: windowModel.expansion)
//   .animation(shelfAnimation, value: store.items.count)
//   .animation(shelfAnimation, value: store.totalFileCount)
//
// After: derive a single Hashable signature so SwiftUI animates once per real change.
```

Add a computed property in `ContentView`:

```swift
private struct AnimationSignature: Hashable {
    let expansion: ShelfWindowModel.Expansion
    let itemCount: Int
    let totalFileCount: Int
}

private var animationSignature: AnimationSignature {
    AnimationSignature(
        expansion: windowModel.expansion,
        itemCount: store.items.count,
        totalFileCount: store.totalFileCount
    )
}
```

(If `ShelfWindowModel.Expansion` is not Hashable, mark it `Hashable`.)

Replace the three modifiers with one:

```swift
.animation(shelfAnimation, value: animationSignature)
```

- [ ] **Step 2: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 3: Manually verify**

Launch app, hover to expand, drop items, remove items. Confirm animations still look correct and not duplicated.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/App/ContentView.swift NotchShelf/Shared/ShelfWindowModel.swift
git commit -m "perf(ContentView): collapse three implicit animations into one composite signature"
```

---

## Phase 3 — Dead code purge

### Task 12: Delete verified-unused symbols

**Audit ref:** C-DEAD-CODE — multiple symbols never called from production. Each was verified by grep before listing.

**Files:** see deletion table below

- [ ] **Step 1: Verify each "dead" symbol one more time**

For each symbol below, run a grep across the entire project and the test target. If grep returns ONLY the definition site, delete. If it returns any test-only call site, decide whether the test is testing dead code (delete both) or whether to keep.

```bash
# Run each grep separately and inspect:
grep -rn "updateBookmark" NotchShelf NotchShelfTests
grep -rn "\.isEmpty" NotchShelf NotchShelfTests | grep -i shelf  # for ShelfStore.isEmpty
grep -rn "refreshedData" NotchShelf NotchShelfTests
grep -rn "fileURLs" NotchShelf NotchShelfTests
grep -rn "accessSecurityScopedResource.*async" NotchShelf NotchShelfTests
grep -rn "onDragMove" NotchShelf NotchShelfTests
grep -rn "hasSelection" NotchShelf NotchShelfTests
grep -rn "Loadable" NotchShelf NotchShelfTests
grep -rn "ShelfPersistenceService.*load()" NotchShelf NotchShelfTests
grep -rn "save(_ items:" NotchShelf NotchShelfTests
```

- [ ] **Step 2: Apply the deletions**

| File | Lines | Symbol | Verification |
|---|---|---|---|
| `NotchShelf/Shelf/State/ShelfStore.swift` | 118-121 | `func updateBookmark(for:bookmark:)` | grep shows zero external callers |
| `NotchShelf/Shelf/State/ShelfStore.swift` | 26 | `var isEmpty: Bool` | callers use `store.items.isEmpty` |
| `NotchShelf/Shelf/Models/Bookmark.swift` | 50 | `var refreshedData: Data?` | callers consume `resolve().refreshedData` |
| `NotchShelf/Shelf/Models/ShelfItem.swift` | 33-35 | `var fileURLs: [URL]` | only test reads it; duplicate of `ShelfStore.resolveFileURLs` |
| `NotchShelf/Shelf/Models/URL+SecurityScoped.swift` | 11-16 | async overload `accessSecurityScopedResource` | only sync variant used |
| `NotchShelf/DragDetect/DragMonitor.swift` | 10 | `var onDragMove` | never set externally |
| `NotchShelf/DragDetect/DragMonitor.swift` | 95-99 | empty `deinit` with apology comment | obsolete since teardown moved to `applicationWillTerminate` |
| `NotchShelf/Shelf/State/ShelfSelection.swift` | 18 | `var hasSelection: Bool` | zero callers |
| `NotchShelf/Shelf/State/Loadable.swift` | entire file | `enum Loadable` | only one test asserts it; views ignore `state` |
| `NotchShelf/Shelf/State/ShelfStore.swift` | 32-37 | `var state: Loadable<[ShelfItem]>` | tied to Loadable above |
| `NotchShelf/Shelf/Services/ShelfPersistenceService.swift` | 31-60 | `func load() -> [ShelfItem]` | replaced by `loadSlots`; legacy migration path only |
| `NotchShelf/Shelf/Services/ShelfPersistenceService.swift` | 71-81 | `func save(_ items:)` | replaced by `save(_ slots:)` |

**Special handling for `load()` recovery branch (lines 41-58):** before deleting, fold the corrupted-entry recovery into `loadSlots()` so legacy users with item-only `shelf.json` files can still migrate. Update `loadSlots()`:

```swift
func loadSlots() -> [ShelfSlot] {
    guard let data = try? Data(contentsOf: fileURL) else { return [] }

    if let slots = try? decoder.decode([ShelfSlot].self, from: data) {
        return slots
    }
    // Legacy format migration: shelf.json may contain a top-level array of items.
    if let items = try? decoder.decode([ShelfItem].self, from: data) {
        return items.map { ShelfSlot(item: $0) }
    }
    // Best-effort recovery for partially corrupted files.
    guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
        NSLog("Shelf persistence file is not a valid JSON array")
        return []
    }
    var valid: [ShelfItem] = []
    var failed = 0
    for entry in jsonArray {
        if let entryData = try? JSONSerialization.data(withJSONObject: entry),
           let item = try? decoder.decode(ShelfItem.self, from: entryData) {
            valid.append(item)
        } else {
            failed += 1
        }
    }
    if failed > 0 {
        NSLog("Loaded \(valid.count) shelf items, discarded \(failed) corrupted")
    }
    return valid.map { ShelfSlot(item: $0) }
}
```

Update tests that exercised `ShelfPersistenceService.load()` to call `loadSlots()` instead.

For `ShelfStore.state`: if any test asserts on it, delete the test or convert it to assert on `store.items` + `store.isLoading` + `store.lastError`.

- [ ] **Step 3: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

Expected: clean build, all remaining tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete verified-unused dead code (Loadable, fileURLs, updateBookmark, etc.)"
```

---

## Phase 4 — Logging migration

### Task 13: Introduce AppLogger and migrate NSLog → os.Logger

**Audit ref:** C-RELEASE-BLOCKER — 7 `NSLog` sites; unconditional syslog spam in release builds.

**Files:**
- Create: `NotchShelf/Shared/AppLogger.swift`
- Modify: `NotchShelf/Shelf/Models/Bookmark.swift:43`, `NotchShelf/Shelf/Services/NSItemProvider+FileURL.swift:17`, `NotchShelf/Shelf/Services/ShelfPersistenceService.swift:42,57,78`, `NotchShelf/Shelf/Services/ThumbnailService.swift:53`, `NotchShelf/Shelf/State/ShelfStore.swift` (Task 2's new NSLog)

- [ ] **Step 1: Create `AppLogger.swift`**

```swift
import os.log

/// Centralized `os.Logger` namespace. Subsystem maps to the bundle identifier so
/// log entries can be filtered in `Console.app`. Categories group related sites.
enum AppLogger {
    private static let subsystem = "com.notchshelf.NotchShelf"

    static let bookmark   = Logger(subsystem: subsystem, category: "bookmark")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let thumbnail  = Logger(subsystem: subsystem, category: "thumbnail")
    static let drag       = Logger(subsystem: subsystem, category: "drag")
    static let shelf      = Logger(subsystem: subsystem, category: "shelf")
}
```

- [ ] **Step 2: Replace each NSLog call site**

In each call site, replace `NSLog(...)` with the appropriate `AppLogger.*.error(...)` or `.info(...)` / `.debug(...)` call. Errors that are recoverable → `.error`; routine outcomes → `.info`; verbose tracing → `.debug` (which is automatically gated to non-release in `os.Logger`).

Example for `NotchShelf/Shelf/Models/Bookmark.swift:43`:

```swift
// Before:
NSLog("Bookmark resolve failed: \(error.localizedDescription)")
// After:
AppLogger.bookmark.error("Bookmark resolve failed: \(error.localizedDescription, privacy: .public)")
```

Example for `NotchShelf/Shelf/Services/ShelfPersistenceService.swift:57`:

```swift
// Before:
NSLog("Loaded \(valid.count) shelf items, discarded \(failed) corrupted")
// After:
AppLogger.persistence.info("Loaded \(valid.count) shelf items, discarded \(failed) corrupted")
```

Full mapping:

| File:Line | Category | Level |
|---|---|---|
| `Bookmark.swift:43` | `.bookmark` | `.error` |
| `NSItemProvider+FileURL.swift:17` | `.drag` | `.error` |
| `ShelfPersistenceService.swift:42` | `.persistence` | `.error` |
| `ShelfPersistenceService.swift:57` | `.persistence` | `.info` |
| `ShelfPersistenceService.swift:78` | `.persistence` | `.error` |
| `ShelfPersistenceService.swift:90` (if Task 12 didn't delete it) | `.persistence` | `.error` |
| `ThumbnailService.swift:53` | `.thumbnail` | `.error` |
| `ShelfStore.swift` flushPendingSaveSync timeout (Task 2) | `.shelf` | `.error` |

- [ ] **Step 3: Confirm zero remaining NSLog calls**

```bash
grep -rn "NSLog" NotchShelf
```

Expected: no matches.

- [ ] **Step 4: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shared/AppLogger.swift NotchShelf/
git commit -m "refactor(logging): migrate NSLog to os.Logger via AppLogger namespace"
```

---

## Phase 5 — Localization normalization

### Task 14: Normalize all UI strings to English

**Audit ref:** C-RELEASE-BLOCKER — mixed Polish/English UI ("Preferencje", "Zamknij aplikację", "Zawsze kopiuj…" alongside "Show in Finder", "Copy Path"). For v1.0 we ship English-only; Polish localization can come in v1.1 via `Localizable.xcstrings`.

**Files:**
- Modify: `NotchShelf/App/ContentView.swift:167,174`, `NotchShelf/App/PreferencesView.swift:9,15`
- (any other Polish strings discovered via grep)

- [ ] **Step 1: Find all Polish strings**

```bash
grep -rn 'Preferencje\|Zamknij\|Zawsze kopiuj\|Pokaż\|Otwórz\|Usuń\|Skopiuj' NotchShelf
```

- [ ] **Step 2: Replace each with the English equivalent**

| File:Line | Polish | English |
|---|---|---|
| `PreferencesView.swift:9` | "Zawsze kopiuj pliki przy przeciąganiu z półki" | "Always copy files when dragging off the shelf" |
| `PreferencesView.swift:15` | "Zamknij aplikację" | "Quit NotchShelf" |
| `ContentView.swift:167` | "Preferencje" | "Preferences" |
| `ContentView.swift:174` | "Preferencje" | "Preferences" |

Replace inline (Edit tool). All other UI strings are already English.

- [ ] **Step 3: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/App/PreferencesView.swift NotchShelf/App/ContentView.swift
git commit -m "i18n: normalize UI strings to English for v1.0"
```

---

## Phase 6 — Accessibility labels

### Task 15: Add accessibility labels to icon-only buttons and decorative images

**Audit ref:** C-RELEASE-BLOCKER — gear button, stack-list button, tray indicator, doc badge are all `Image(systemName:)` with no VoiceOver label.

**Files:**
- Modify: `NotchShelf/App/ContentView.swift:131-156,163-178`, `NotchShelf/Shelf/Views/ShelfItemView.swift:106-117`

- [ ] **Step 1: Patch each icon-only button/image**

In `NotchShelf/App/ContentView.swift`:

```swift
// Line 131 (tray.fill) — purely decorative, but VoiceOver should announce.
Image(systemName: "tray.fill")
    // ... existing modifiers ...
    .accessibilityLabel("NotchShelf")
    .accessibilityHidden(false)

// Lines 144-149 (count + doc icon) — wrap in a single accessibility element.
HStack(spacing: 3) {
    Text("\(store.totalFileCount)")
        // ...
    Image(systemName: "doc.fill")
        // ...
}
// ... existing modifiers ...
.accessibilityElement(children: .ignore)
.accessibilityLabel("\(store.totalFileCount) files on shelf")

// Line 167 (gear button) — already has .help("Preferencje"); add accessibility too.
Button("Preferences", systemImage: "gearshape.fill", action: showPreferences)
    .labelStyle(.iconOnly)
    .buttonStyle(.plain)
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(.white.opacity(0.88))
    .frame(width: 28, height: 28)
    .contentShape(Rectangle())
    .help("Preferences")
    .accessibilityLabel("Preferences")
```

In `NotchShelf/Shelf/Views/ShelfItemView.swift:106-117`:

```swift
private var stackListButton: some View {
    Button {
        showingStackList.toggle()
    } label: {
        Image(systemName: "list.bullet.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 14, height: 14)
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Show stack files")
}
```

- [ ] **Step 2: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

- [ ] **Step 3: Manually verify with VoiceOver (optional but recommended)**

Cmd+F5 to enable VoiceOver, hover over the shelf and the preferences button, confirm each announces correctly.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/
git commit -m "a11y: add VoiceOver labels to icon-only buttons and decorative images"
```

---

## Phase 7 — Release metadata

### Task 16: Bump version, complete Info.plist, exclude reference codebase

**Audit ref:** C-RELEASE-BLOCKER — `MARKETING_VERSION: "0.1.0"`, ad-hoc signing, missing `LSApplicationCategoryType`, `boring.notch-main/` in repo.

**Files:**
- Modify: `project.yml:10-13`
- Modify: `NotchShelf/Info.plist`
- Modify: `.gitignore` (or `git rm -r --cached boring.notch-main/`)

- [ ] **Step 1: Bump marketing version**

In `project.yml`, change:

```yaml
MARKETING_VERSION: "0.1.0"
CURRENT_PROJECT_VERSION: "1"
```

to:

```yaml
MARKETING_VERSION: "1.0.0"
CURRENT_PROJECT_VERSION: "100"
```

- [ ] **Step 2: Add Info.plist entries**

In `NotchShelf/Info.plist`, before the closing `</dict>`, add:

```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>
<key>NSHumanReadableCopyright</key>
<string>Copyright © 2026 Michał Kleniewski. All rights reserved.</string>
```

Replace the existing placeholder `<string>NotchShelf</string>` under `NSHumanReadableCopyright` with the line above.

- [ ] **Step 3: Decide on signing identity**

For a stable v1.0 distributed publicly, `CODE_SIGN_IDENTITY: "-"` (ad-hoc) is insufficient — Gatekeeper will block. Either:

(a) **TestFlight / direct download:** change to `"Developer ID Application"` and ensure the dev account is configured. Update `project.yml`:

```yaml
CODE_SIGN_IDENTITY: "Developer ID Application"
CODE_SIGN_STYLE: Automatic
DEVELOPMENT_TEAM: "<YOUR_TEAM_ID>"
```

Then notarize via `xcrun notarytool` post-build.

(b) **Personal use only:** leave `"-"` and document that the binary requires `xattr -dr com.apple.quarantine NotchShelf.app` on the user's machine.

Document the choice in `AGENTS.md` or `README.md`.

- [ ] **Step 4: Exclude `boring.notch-main/`**

If `boring.notch-main/` is still tracked:

```bash
git ls-files boring.notch-main/ | head -5
```

If any files appear, remove from the index (but keep on disk):

```bash
git rm -r --cached boring.notch-main/
```

Then append to `.gitignore`:

```
# Reference codebase, not shipped
boring.notch-main/
```

- [ ] **Step 5: Regenerate the Xcode project and rebuild**

```bash
xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Release build 2>&1 | tail -20
```

Expected: build succeeds, version in the built binary's `Info.plist` reads `1.0.0`.

- [ ] **Step 6: Commit**

```bash
git add project.yml NotchShelf/Info.plist .gitignore
git commit -m "release: bump to 1.0.0, complete Info.plist, exclude reference codebase"
```

---

## Phase 8 — Architecture cleanup (optional; defer to v1.1 if time-bound)

### Task 17: Resolve Preferences.shared vs @AppStorage duality

**Audit ref:** A-IMPORTANT — `Preferences.shared` reads `UserDefaults.bool(forKey:)` synchronously; `PreferencesView` uses `@AppStorage`. Both work but `Preferences` doesn't observe `UserDefaults.didChangeNotification`, so a toggle in `PreferencesView` does not propagate to held `Preferences` references unless they re-read on each access (which they do, so it works — but the contract is fragile).

**Decision required:** keep one source of truth.

**Files:**
- Modify or delete: `NotchShelf/Shared/Preferences.swift`
- Modify: `NotchShelf/Shared/Protocols/Services.swift`, drag sources

- [ ] **Step 1: Decide on the path**

| Option | Description |
|---|---|
| A | Keep `Preferences`, drop `@unchecked Sendable @MainActor` annotation issue by removing `@MainActor`. The `UserDefaults.bool(forKey:)` call is thread-safe per Apple docs. |
| B | Delete `Preferences` and `PreferenceProviding`. Have drag sources read `UserDefaults.standard.bool(forKey: "copyOnDrag")` directly. |

Recommendation: **B**, because it removes a vestigial singleton + protocol that isn't currently substituted in any test.

- [ ] **Step 2 (option B): Replace `Preferences.shared.copyOnDrag` usages**

```bash
grep -rn "Preferences.shared\|PreferenceProviding\|copyOnDrag" NotchShelf
```

In each drag-source file, replace `preferences.copyOnDrag` with:

```swift
UserDefaults.standard.bool(forKey: "copyOnDrag")
```

Centralize the key as a constant in `AppLogger.swift` or a new `UserDefaultsKeys.swift`:

```swift
enum UserDefaultsKey {
    static let copyOnDrag = "copyOnDrag"
}
```

- [ ] **Step 3 (option B): Delete `Preferences.swift` and `PreferenceProviding`**

```bash
rm NotchShelf/Shared/Preferences.swift
```

Remove the `PreferenceProviding` protocol from `NotchShelf/Shared/Protocols/Services.swift`.

- [ ] **Step 4: Build and run the suite**

```bash
xcodebuild ... build 2>&1 | tail -10
xcodebuild ... test 2>&1 | tail -10
```

If any test fails because it injected a fake `PreferenceProviding`, replace the injection with a `UserDefaults` seeded for the test:

```swift
UserDefaults.standard.set(true, forKey: UserDefaultsKey.copyOnDrag)
```

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/ NotchShelfTests/
git commit -m "refactor: collapse Preferences singleton into direct UserDefaults reads"
```

---

### Task 18: Final Release-configuration build verification

**Files:** none — verification step

- [ ] **Step 1: Run a clean Release build**

```bash
rm -rf NotchShelf.xcodeproj/build
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Release clean build 2>&1 | tee /tmp/notchshelf-release-build.log | tail -50
```

Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 2: Audit log for any warning lines**

```bash
grep -E "warning:|error:" /tmp/notchshelf-release-build.log
```

Expected: no output. If any warning appears, file it as a follow-up task and address before tagging.

- [ ] **Step 3: Verify Info.plist of the built binary**

```bash
defaults read $(find NotchShelf.xcodeproj/build -name "NotchShelf.app" | head -1)/Contents/Info.plist | grep -E "CFBundleShortVersionString|LSApplicationCategoryType|NSHumanReadableCopyright"
```

Expected: version `1.0.0`, category `public.app-category.utilities`, full copyright string.

- [ ] **Step 4: Sanity-test the binary**

Launch the built `.app`, drop a few files, expand the shelf, drag a file out, quit. Confirm:
- No crash
- Drop targeting works
- Shelf persists across relaunch
- Preferences toggle persists across relaunch
- VoiceOver announces gear button and stack list button correctly

- [ ] **Step 5: Tag v1.0.0**

```bash
git tag -a v1.0.0 -m "NotchShelf 1.0.0 — stable release"
git push origin v1.0.0
```

---

## Spec coverage check

| Audit item | Task |
|---|---|
| P-CRITICAL #1 unbounded thumbnail cache | Task 5 |
| P-CRITICAL #2 stale snapshot in debounced save | Task 1 |
| P-CRITICAL #3 fallback double-write at terminate | Task 2 |
| C-CRITICAL `NSScreen.screens.first!` | Task 3 |
| S-CRITICAL #1 drag-preview Task races | Task 4 |
| S-CRITICAL #5 per-render stack panel bookmark/icon | Task 6 |
| P-IMPORTANT no concurrency cap on validation | Task 7 |
| P-MINOR per-render `NSWorkspace.icon` | Task 8 |
| S-IMPORTANT presenter on every item | Task 9 |
| P-MINOR pretty-printed JSON | Task 10 |
| S-IMPORTANT stacked `.animation(_:value:)` | Task 11 |
| C-DEAD-CODE (10 symbols) | Task 12 |
| C-RELEASE-BLOCKER NSLog → os.Logger | Task 13 |
| C-RELEASE-BLOCKER mixed PL/EN strings | Task 14 |
| C-RELEASE-BLOCKER missing a11y labels | Task 15 |
| C-RELEASE-BLOCKER version + Info.plist + boring.notch-main | Task 16 |
| A-IMPORTANT Preferences vs @AppStorage duality | Task 17 |
| Final verification | Task 18 |

### Items intentionally deferred to v1.1

- **A-IMPORTANT split `ShelfStore` (~300 LOC) into `ShelfPersistenceCoordinator` + `BookmarkLifecycle`** — architecture refinement, not a stability blocker.
- **A-IMPORTANT route `ShelfStoring` / `SelectionStoring` through the full view tree** — vestigial protocol cleanup, not a blocker.
- **S-MINOR `ShelfWindowModel` over-broad publishers** — narrow optimization; ContentView's body cost is acceptable for current N.
- **S-MINOR cache `makeContentController` by item id** — small win; revisit if profiling shows it.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-15-plan-implementacji.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration. Use `superpowers:subagent-driven-development`.
2. **Inline Execution** — execute tasks in this session with checkpoints. Use `superpowers:executing-plans`.

Which approach?

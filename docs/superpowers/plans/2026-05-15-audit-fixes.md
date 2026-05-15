# NotchShelf Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply all critical + important fixes from the 2026-05-15 architecture audit without regressing behavior or breaking the test suite.

**Architecture:** Five sequential phases — (1) safe local fixes, (2) performance, (3) split `ShelfItemView`, (4) explicit state + ViewData, (5) DI shim with protocols. Each task is TDD-style where new behavior is introduced, refactor-style (existing tests must stay green) where pure restructuring.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI + AppKit, Swift Testing (`import Testing`, `@Test`, `#expect`), XcodeGen (`project.yml`), `scripts/test.sh` runner.

**Test command (used in every "verify" step below):**

```bash
./scripts/test.sh
```

**Commit convention:** match existing style (`feat:`, `fix:`, `refactor:`, `chore:`). One logical change per commit.

---

## Phase 1 — Safe local fixes

### Task 1: PreferencesView → `@AppStorage`

**Background:** `@State private var copyOnDrag = Preferences.shared.copyOnDrag` reads once at view-init time; the toggle never reflects external mutations and the manual `onChange` mirror is fragile.

**Files:**
- Modify: `NotchShelf/App/PreferencesView.swift`

- [ ] **Step 1: Replace local state with `@AppStorage`**

Replace the whole struct body to use the system-managed UserDefaults binding:

```swift
import AppKit
import SwiftUI

struct PreferencesView: View {
    @AppStorage("copyOnDrag") private var copyOnDrag = false

    var body: some View {
        Form {
            Toggle("Zawsze kopiuj pliki przy przeciąganiu z półki", isOn: $copyOnDrag)

            Divider()

            HStack {
                Spacer()
                Button("Zamknij aplikację", role: .destructive, action: quitApplication)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }

    private func quitApplication() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Verify the `copyOnDrag` key is identical to `Preferences.Key.copyOnDrag`**

Run:
```bash
grep -n 'copyOnDrag' NotchShelf/Shared/Preferences.swift
```
Expected: `static let copyOnDrag = "copyOnDrag"` — both sides must agree on the literal `"copyOnDrag"`.

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all existing tests pass.

- [ ] **Step 4: Manual smoke check**

Build and launch the app, open Preferences, toggle the checkbox, drag a file off the shelf, confirm copy-only semantics. Toggle back, confirm move/copy semantics restored. Open preferences twice to confirm the toggle reflects the persisted state on both opens.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/App/PreferencesView.swift
git commit -m "fix: bind PreferencesView toggle to @AppStorage"
```

---

### Task 2: Remove force-unwraps in AppKit drag-source views

**Background:** `var sourceItem: ShelfItem!` and `var item: ShelfItem!` in [ShelfItemView.swift:391](../../NotchShelf/Shelf/Views/ShelfItemView.swift#L391) and [ShelfItemView.swift:516](../../NotchShelf/Shelf/Views/ShelfItemView.swift#L516) trap at runtime if AppKit dispatches a mouse event before `updateNSView` fires (rare but possible).

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Convert `StackFileDragView.sourceItem` to optional + guarded callsites**

In `private struct StackFileDragHandler` → `final class StackFileDragView`:

```swift
final class StackFileDragView: NSView, NSDraggingSource {
    var sourceItem: ShelfItem?
    var bookmarkData = Data()
    var title = ""
    var previewImage = NSImage()
    // ...rest unchanged...
```

Update `draggingSession(_:willBeginAt:)`:

```swift
func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
    ShelfSelection.shared.beginDrag()
    guard !removedFromShelf, let sourceItem else { return }
    ShelfStore.shared.remove(bookmarkData: bookmarkData, from: sourceItem)
    ShelfSelection.shared.clear()
    removedFromShelf = true
}
```

- [ ] **Step 2: Convert `DraggableClickView.item` to optional + guarded callsites**

In `private struct DraggableClickHandler` → `final class DraggableClickView`:

```swift
final class DraggableClickView: NSView, NSDraggingSource {
    var item: ShelfItem?
    weak var viewModel: ShelfItemViewModel?
    // ...rest unchanged...
```

Update `startDragSession`:

```swift
private func startDragSession(with event: NSEvent) {
    guard let item else { return }
    let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
    let itemsToDrag: [ShelfItem] =
        (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
    // ...rest unchanged...
```

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 4: Manual smoke check**

Drag single + multi-selection from the shelf out to Finder. Drag from stack popover. Confirm no crashes and correct removal.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "fix: remove force-unwrapped IUOs in drag-source views"
```

---

### Task 3: Remove dead code `ShelfStore.resolveAndUpdateBookmark`

**Background:** `resolveAndUpdateBookmark(for:)` is defined at [ShelfStore.swift:138](../../NotchShelf/Shelf/State/ShelfStore.swift#L138) but never called from production or tests.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`

- [ ] **Step 1: Confirm zero references**

Run:
```bash
grep -rn "resolveAndUpdateBookmark" NotchShelf NotchShelfTests
```
Expected: only the definition line in `ShelfStore.swift`.

- [ ] **Step 2: Delete the function**

Remove lines 137-144 (the `/// Resolves an item's URL, refreshing a stale bookmark immediately.` comment block and the function body):

```swift
    /// Resolves an item's URL, refreshing a stale bookmark immediately.
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        let result = Bookmark(data: item.bookmarkData).resolve()
        if let refreshed = result.refreshedData, refreshed != item.bookmarkData {
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }
```

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift
git commit -m "chore: drop unused ShelfStore.resolveAndUpdateBookmark"
```

---

### Task 4: Move invalid-item cleanup from `ContentView.onAppear` to `AppDelegate`

**Background:** SwiftUI `onAppear` can fire multiple times during the app's lifecycle (scene reactivation). Cleanup should happen once at launch.

**Files:**
- Modify: `NotchShelf/App/AppDelegate.swift`
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Add cleanup call in `AppDelegate.applicationDidFinishLaunching`**

Edit `applicationDidFinishLaunching`:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    guard !Self.isRunningTests else { return }
    NSApp.setActivationPolicy(.accessory)
    windowController = NotchWindowController(windowModel: windowModel)
    setupDragMonitor()
    ShelfStore.shared.cleanupInvalidItems()
}
```

- [ ] **Step 2: Remove `onAppear` cleanup in `ContentView`**

Delete this line from the bottom of `body` in `ContentView`:

```swift
.onAppear { ShelfStore.shared.cleanupInvalidItems() }
```

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/App/AppDelegate.swift NotchShelf/App/ContentView.swift
git commit -m "refactor: run shelf cleanup once at launch instead of on every view appear"
```

---

### Task 5: Replace `MainActor.assumeIsolated` in `DragMonitor.deinit` with explicit `invalidate()`

**Background:** Swift 6 does not guarantee `deinit` runs on the MainActor even when the class is `@MainActor`. `MainActor.assumeIsolated` traps if ARC drops the last reference from a background thread.

**Files:**
- Modify: `NotchShelf/DragDetect/DragMonitor.swift`
- Modify: `NotchShelf/App/AppDelegate.swift`

- [ ] **Step 1: Drop the unsafe `deinit` body and rely on `stopMonitoring`**

Replace the bottom of `DragMonitor` (the `deinit` block):

```swift
    deinit {
        // Caller must invoke stopMonitoring() before releasing the last reference.
        // We intentionally do not touch NSEvent monitors here because Swift 6 does
        // not guarantee deinit runs on the MainActor.
    }
```

- [ ] **Step 2: Wire up explicit teardown in `AppDelegate.applicationWillTerminate`**

Add to `AppDelegate`:

```swift
func applicationWillTerminate(_ notification: Notification) {
    dragMonitor?.stopMonitoring()
    dragMonitor = nil
}
```

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/DragDetect/DragMonitor.swift NotchShelf/App/AppDelegate.swift
git commit -m "fix: tear down DragMonitor explicitly instead of from deinit"
```

---

### Task 6: Strip unnecessary `Task` wrappers from `ShelfActionService`

**Background:** [ShelfActionService.swift:38-42](../../NotchShelf/Shelf/Services/ShelfActionService.swift#L38-L42) wraps purely synchronous AppKit work in `Task { ... }`. The wrap loses completion ordering and adds main-actor hop without benefit.

**Files:**
- Modify: `NotchShelf/Shelf/Services/ShelfActionService.swift`

- [ ] **Step 1: Rewrite the helpers as direct synchronous calls**

Replace `handleBookmarkedFile` and `handleBookmarkedFiles` with their synchronous form:

```swift
    private static func handleBookmarkedFile(
        _ bookmarkData: Data,
        action: (URL) -> Void
    ) {
        guard let url = Bookmark(data: bookmarkData).resolveURL() else { return }
        url.accessSecurityScopedResource { action($0) }
    }

    private static func handleBookmarkedFiles(
        _ bookmarkData: [Data],
        action: ([URL]) -> Void
    ) {
        let urls = bookmarkData.compactMap { Bookmark(data: $0).resolveURL() }
        guard !urls.isEmpty else { return }
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        action(urls)
    }
```

- [ ] **Step 2: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 3: Manual smoke check**

Right-click a shelf item → Open / Show in Finder / Copy Path. Confirm each action fires immediately.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfActionService.swift
git commit -m "refactor: drop unnecessary Task wrappers in ShelfActionService"
```

---

### Task 7: Debounce persistence save in `ShelfStore`

**Background:** [ShelfStore.swift:11-13](../../NotchShelf/Shelf/State/ShelfStore.swift#L11-L13) writes JSON to disk in `didSet` for every mutation. Multi-file drops / stack splits / stale-bookmark refreshes can fire 3+ writes per user action.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Modify: `NotchShelfTests/ShelfStoreTests.swift`

- [ ] **Step 1: Write a failing test for debounced save**

Add to `ShelfStoreTests.swift`:

```swift
@MainActor @Test func storeDebouncesPersistenceWrites() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let persistence = ShelfPersistenceService(directory: dir)
    let store = ShelfStore(persistence: persistence)

    let a = try makeFileItem(named: "a.txt")
    let b = try makeFileItem(named: "b.txt")
    store.add([a])
    store.add([b])

    // Before the debounce flushes, the file should not yet reflect the latest items.
    let immediateLoad = ShelfPersistenceService(directory: dir).load()
    #expect(immediateLoad.count <= 2)

    // Allow the debounce window to elapse.
    try await Task.sleep(for: .milliseconds(300))
    await store.flushPendingSave()

    let flushed = ShelfPersistenceService(directory: dir).load()
    #expect(flushed.count == 2)
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `./scripts/test.sh`
Expected: build failure — `flushPendingSave` does not exist yet.

- [ ] **Step 3: Implement debounce in `ShelfStore`**

Replace the `items` declaration and add a debounce field + `flushPendingSave`:

```swift
    @Published private(set) var items: [ShelfItem] = [] {
        didSet { schedulePersistenceSave() }
    }

    @Published var isLoading: Bool = false

    private var saveTask: Task<Void, Never>?
    private let saveDebounce: Duration = .milliseconds(200)
```

Add the helper methods (place them next to the existing persistence/bookmark logic):

```swift
    private func schedulePersistenceSave() {
        saveTask?.cancel()
        let snapshot = items
        let persistence = self.persistence
        let debounce = saveDebounce
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await Task.detached { persistence.save(snapshot) }.value
        }
    }

    /// Flushes any pending debounced save synchronously. Intended for tests and
    /// `applicationWillTerminate`.
    func flushPendingSave() async {
        saveTask?.cancel()
        saveTask = nil
        let snapshot = items
        await Task.detached { [persistence] in persistence.save(snapshot) }.value
    }
```

Replace the `init` body so the initial load does not trigger a save:

```swift
    init(persistence: ShelfPersistenceService = .shared) {
        self.persistence = persistence
        let loaded = persistence.load()
        // Assigning to the backing storage bypasses didSet on initial load.
        _items = Published(initialValue: loaded)
    }
```

- [ ] **Step 4: Flush on terminate**

Edit `AppDelegate.applicationWillTerminate`:

```swift
func applicationWillTerminate(_ notification: Notification) {
    dragMonitor?.stopMonitoring()
    dragMonitor = nil
    // Block until the most recent shelf state is on disk so a crash-free quit
    // never loses items added moments before quit.
    let semaphore = DispatchSemaphore(value: 0)
    Task { @MainActor in
        await ShelfStore.shared.flushPendingSave()
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 1.0)
}
```

- [ ] **Step 5: Run tests**

Run: `./scripts/test.sh`
Expected: all tests pass including the new debounce test.

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelf/App/AppDelegate.swift NotchShelfTests/ShelfStoreTests.swift
git commit -m "perf: debounce ShelfStore persistence writes"
```

---

### Task 8: Cancellable debounce in `ShelfItemView.onChange(of: viewModel.isDropTargeted)`

**Background:** [ShelfItemView.swift:58-64](../../NotchShelf/Shelf/Views/ShelfItemView.swift#L58-L64) spawns a fresh `Task { try? await Task.sleep(...) }` on every change with no cancellation. Stale tasks may overwrite newer state.

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Track and cancel the debounce task**

Add a `@State` field on `ShelfItemView`:

```swift
    @State private var debouncedDropTarget = false
    @State private var dropTargetDebounceTask: Task<Void, Never>?
```

Replace the `onChange(of: viewModel.isDropTargeted)` block:

```swift
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            windowModel.dragTargeting = targeted
            dropTargetDebounceTask?.cancel()
            dropTargetDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                debouncedDropTarget = targeted
            }
        }
```

- [ ] **Step 2: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 3: Manual smoke check**

Drag a file rapidly in and out of the shelf — visual highlight should snap to the latest state with no flicker stuck on a stale value.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "fix: cancel stale drop-target debounce tasks in ShelfItemView"
```

---

## Phase 2 — Performance fixes

### Task 9: Parallel validation in `ShelfStore.cleanupInvalidItems`

**Background:** [ShelfStore.swift:112-126](../../NotchShelf/Shelf/State/ShelfStore.swift#L112-L126) validates bookmarks one at a time in a `for` loop. Each `Bookmark.validate()` starts/stops security-scoped access and calls `FileManager.fileExists`. For 50 items, this serializes 50 short waits.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`

- [ ] **Step 1: Rewrite using `withTaskGroup`**

Replace `cleanupInvalidItems`:

```swift
    /// Removes items whose bookmark no longer resolves to an existing file.
    /// Items added while validation is in flight are preserved.
    func cleanupInvalidItems() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = self.items
            let validIDs = await Self.validateInParallel(snapshot)
            let snapshotIDs = Set(snapshot.map(\.id))
            // Keep validated items, plus anything added since the snapshot.
            self.items = self.items.filter { validIDs.contains($0.id) || !snapshotIDs.contains($0.id) }
        }
    }

    private static func validateInParallel(_ snapshot: [ShelfItem]) async -> Set<ShelfItem.ID> {
        await withTaskGroup(of: (ShelfItem.ID, Bool).self) { group in
            for item in snapshot {
                group.addTask {
                    let isValid = await Bookmark(data: item.bookmarkData).validate()
                    return (item.id, isValid)
                }
            }
            var validIDs: Set<ShelfItem.ID> = []
            for await (id, isValid) in group where isValid {
                validIDs.insert(id)
            }
            return validIDs
        }
    }
```

- [ ] **Step 2: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass (no test regression; behavior is identical, throughput differs).

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift
git commit -m "perf: validate shelf bookmarks in parallel during cleanup"
```

---

### Task 10: Cache `ShelfItem.identityKey`

**Background:** `identityKey` resolves bookmarks every time it is read. `ShelfStore.add()` builds an identity set over the entire current shelf for every new item.

**Files:**
- Modify: `NotchShelf/Shelf/Models/ShelfItem.swift`
- Modify: `NotchShelfTests/ShelfItemTests.swift`

- [ ] **Step 1: Write a failing test for cache stability**

Add to `ShelfItemTests.swift`:

```swift
@Test func shelfItemIdentityKeyIsStableAcrossReads() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("a.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)

    let first = item.identityKey
    let second = item.identityKey
    #expect(first == second)
    #expect(first.hasPrefix("file://"))
}
```

This already passes — it sets up the baseline expectation before adding the cache. Run it to confirm:

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 2: Add a memoized identityKey to `ShelfItem`**

Because `ShelfItem` is a `struct` and `Equatable` / `Codable`, the cache cannot be a stored property (it would change equality and serialization). Instead, fold the resolve-once optimization into `ShelfStore.add()` only — pre-compute keys into a local dictionary keyed by `ShelfItem.ID`:

Replace `ShelfStore.add`:

```swift
    /// Appends new items, skipping any whose `identityKey` already exists.
    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        // Pre-compute identity keys to avoid resolving every bookmark on every comparison.
        var keys: [ShelfItem.ID: String] = [:]
        for item in merged { keys[item.id] = item.identityKey }
        var seen = Set(keys.values)

        for item in newItems {
            let folderKey = item.sourceFolderKey
            if let folderKey,
               let idx = merged.firstIndex(where: {
                   $0.sourceFolderKey == folderKey && ($0.isStack || item.isStack)
               }) {
                let updated = merged[idx].merging(with: item)
                if let oldKey = keys[merged[idx].id] {
                    seen.remove(oldKey)
                }
                merged[idx] = updated
                let newKey = updated.identityKey
                keys[updated.id] = newKey
                seen.insert(newKey)
                continue
            }
            let key = item.identityKey
            guard !seen.contains(key) else { continue }
            merged.append(item)
            keys[item.id] = key
            seen.insert(key)
        }
        items = merged
    }
```

This guarantees each item's `identityKey` is resolved at most once per `add` call.

- [ ] **Step 3: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass (`storeAddDeduplicatesBySamePath`, `storeMergesSameFolderItemsIntoStack`, etc. continue to hold).

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/ShelfItemTests.swift
git commit -m "perf: precompute identity keys in ShelfStore.add"
```

---

### Task 11: Track and cancel `ShelfStore.load` task

**Background:** [ShelfStore.swift:103-108](../../NotchShelf/Shelf/State/ShelfStore.swift#L103-L108) spawns an unowned task. Two quick drops result in two parallel tasks racing into `add`.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`

- [ ] **Step 1: Store the load task and cancel on re-entry**

Add a field next to `saveTask`:

```swift
    private var loadTask: Task<Void, Never>?
```

Replace `load(_:)`:

```swift
    /// Loads dropped providers into the shelf asynchronously. Cancels any in-flight load.
    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        loadTask?.cancel()
        isLoading = true
        nonisolated(unsafe) let sendableProviders = providers
        loadTask = Task { @MainActor [weak self] in
            let dropped = await ShelfDropService.items(from: sendableProviders)
            guard !Task.isCancelled else { return }
            self?.add(dropped)
            self?.isLoading = false
        }
    }
```

- [ ] **Step 2: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift
git commit -m "fix: cancel in-flight shelf load when a new drop arrives"
```

---

## Phase 3 — Split `ShelfItemView`

> **Why:** `ShelfItemView.swift` is 643 lines covering five distinct responsibilities. We split it without changing behavior — existing tests must remain green. Mark every commit as `refactor:`.

### Task 12: Extract stack-list panel into its own file

**Files:**
- Create: `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Create the new file with the moved code**

Create directory if needed:
```bash
mkdir -p NotchShelf/Shelf/Views/Stack
```

Move these three types (verbatim, drop `private`):
- `StackMenuEntry` (struct)
- `StackFileListView` (View)
- `StackFileRowView` (View)
- `StackFileListPanelPresenter` (NSViewRepresentable) and its `Coordinator`

Into `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`:

```swift
import AppKit
import SwiftUI

struct StackMenuEntry {
    let id: Int
    let title: String
    let bookmarkData: Data
    let fileURL: URL?
}

struct StackFileListView: View {
    let item: ShelfItem

    private var entries: [StackMenuEntry] {
        item.allBookmarkData.enumerated().map { index, data in
            let url = Bookmark(data: data).resolveURL()
            return StackMenuEntry(
                id: index,
                title: url?.lastPathComponent ?? "Unknown file",
                bookmarkData: data,
                fileURL: url
            )
        }
    }

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
    }
}

struct StackFileRowView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry

    private var icon: NSImage {
        if let url = entry.fileURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

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
    }
}

struct StackFileListPanelPresenter: NSViewRepresentable {
    let item: ShelfItem
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(item: item, anchoredTo: nsView, isPresented: isPresented)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.close()
    }

    @MainActor
    final class Coordinator {
        private let isPresented: Binding<Bool>
        private var panel: NSPanel?
        private var localMonitor: Any?
        private var globalMonitor: Any?

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func update(item: ShelfItem, anchoredTo anchorView: NSView, isPresented: Bool) {
            guard isPresented else {
                close()
                return
            }

            let panel = panel ?? makePanel()
            self.panel = panel
            panel.contentViewController = makeContentController(for: item)
            position(panel, anchoredTo: anchorView, itemCount: item.allBookmarkData.count)

            if !panel.isVisible {
                panel.orderFrontRegardless()
                installOutsideClickMonitor(anchorView: anchorView)
            }
        }

        func close() {
            panel?.orderOut(nil)
            panel = nil
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
        }

        private func makePanel() -> NSPanel {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            return panel
        }

        private func makeContentController(for item: ShelfItem) -> NSHostingController<some View> {
            let height = min(CGFloat(item.allBookmarkData.count) * 34 + 12, 220)
            let view = StackFileListView(item: item)
                .frame(width: 240, height: height)
                .background(Color.clear)
            let controller = NSHostingController(rootView: view)
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor
            return controller
        }

        private func position(_ panel: NSPanel, anchoredTo anchorView: NSView, itemCount: Int) {
            guard let window = anchorView.window else { return }
            let width: CGFloat = 240
            let height = min(CGFloat(itemCount) * 34 + 12, 220)
            panel.setContentSize(NSSize(width: width, height: height))

            let anchorRect = anchorView.convert(anchorView.bounds, to: nil)
            let screenRect = window.convertToScreen(anchorRect)
            let x = screenRect.midX - width / 2
            let y = screenRect.minY - height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        private func installOutsideClickMonitor(anchorView: NSView) {
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak anchorView] event in
                guard let self else { return event }
                if event.window === self.panel {
                    return event
                }
                if let anchorView, event.window === anchorView.window {
                    let point = anchorView.convert(event.locationInWindow, from: nil)
                    if anchorView.bounds.contains(point) { return event }
                }
                self.isPresented.wrappedValue = false
                self.close()
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.isPresented.wrappedValue = false
                    self?.close()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Delete the moved types from `ShelfItemView.swift`**

Remove the four `private struct/final class` declarations of `StackMenuEntry`, `StackFileListView`, `StackFileListPanelPresenter`, `StackFileRowView` from `ShelfItemView.swift`. Leave `StackFileDragHandler` in place — Task 13 moves it.

- [ ] **Step 3: Regenerate the Xcode project**

Run:
```bash
xcodegen generate
```

- [ ] **Step 4: Build & test**

Run: `./scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/Stack/ NotchShelf/Shelf/Views/ShelfItemView.swift NotchShelf.xcodeproj
git commit -m "refactor: extract stack-list panel into Shelf/Views/Stack/"
```

---

### Task 13: Extract stack-file drag source into its own file

**Files:**
- Create: `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Create the new file**

```bash
mkdir -p NotchShelf/Shelf/Views/Drag
```

Move `StackFileDragHandler` and its inner `StackFileDragView` into `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`. Drop the leading `private`:

```swift
import AppKit
import SwiftUI

struct StackFileDragHandler: NSViewRepresentable {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let previewImage: NSImage

    func makeNSView(context: Context) -> StackFileDragView {
        let view = StackFileDragView()
        view.sourceItem = sourceItem
        view.bookmarkData = entry.bookmarkData
        view.title = entry.title
        view.previewImage = previewImage
        return view
    }

    func updateNSView(_ nsView: StackFileDragView, context: Context) {
        nsView.sourceItem = sourceItem
        nsView.bookmarkData = entry.bookmarkData
        nsView.title = entry.title
        nsView.previewImage = previewImage
    }

    final class StackFileDragView: NSView, NSDraggingSource {
        var sourceItem: ShelfItem?
        var bookmarkData = Data()
        var title = ""
        var previewImage = NSImage()

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURL: URL?
        private var didStartDrag = false
        private var removedFromShelf = false

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            didStartDrag = false
        }

        override func mouseUp(with event: NSEvent) {
            guard !didStartDrag else { return }
            ShelfActionService.open(bookmarkData: bookmarkData)
            mouseDownEvent = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }
            let distance = hypot(
                event.locationInWindow.x - down.locationInWindow.x,
                event.locationInWindow.y - down.locationInWindow.y
            )
            if distance > dragThreshold {
                startDragSession(with: event)
                mouseDownEvent = nil
                didStartDrag = true
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            guard let url = Bookmark(data: bookmarkData).resolveURL() else { return }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(url.path, forType: .string)

            if url.startAccessingSecurityScopedResource() {
                draggedURL = url
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: previewImage.size),
                contents: previewImage
            )

            removedFromShelf = false
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if Preferences.shared.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.copy, .move, .generic]
            @unknown default:
                return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelection.shared.beginDrag()
            guard !removedFromShelf, let sourceItem else { return }
            ShelfStore.shared.remove(bookmarkData: bookmarkData, from: sourceItem)
            ShelfSelection.shared.clear()
            removedFromShelf = true
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            draggedURL?.stopAccessingSecurityScopedResource()
            draggedURL = nil
            removedFromShelf = false
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}
```

- [ ] **Step 2: Delete the moved code from `ShelfItemView.swift`**

Remove the entire `// MARK: - AppKit drag source` section through the end of `StackFileDragHandler` (but keep `DraggableClickHandler`).

- [ ] **Step 3: Regenerate the project & test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/Drag/ NotchShelf/Shelf/Views/ShelfItemView.swift NotchShelf.xcodeproj
git commit -m "refactor: extract stack-file drag source into Shelf/Views/Drag/"
```

---

### Task 14: Extract `DraggableClickHandler` into its own file

**Files:**
- Create: `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [x] **Step 1: Create the new file**

Move `DraggableClickHandler` + its inner `DraggableClickView` (no `private`) into `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`:

```swift
import AppKit
import SwiftUI

struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    @Binding var cachedPreviewImage: NSImage?
    let onClick: (NSEvent, NSView) -> Void
    let onRightClick: (NSEvent, NSView) -> Void

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.viewModel = viewModel
        view.dragPreviewImage = cachedPreviewImage ?? viewModel.icon
        view.onClick = onClick
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem?
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(event, self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            onClick?(event, self)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }
            let distance = hypot(
                event.locationInWindow.x - down.locationInWindow.x,
                event.locationInWindow.y - down.locationInWindow.y
            )
            if distance > dragThreshold {
                startDragSession(with: event)
                mouseDownEvent = nil
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            guard let item else { return }
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag

            var draggingItems: [NSDraggingItem] = []
            for dragItem in itemsToDrag {
                let urls = ShelfStore.shared.resolveFileURLs(for: dragItem)
                if urls.isEmpty {
                    if let pasteboardItem = pasteboardItem(displayName: dragItem.displayName) {
                        draggingItems.append(draggingItem(for: pasteboardItem))
                    }
                    continue
                }
                for url in urls {
                    guard let pasteboardItem = pasteboardItem(for: url) else { continue }
                    draggingItems.append(draggingItem(for: pasteboardItem))
                }
            }
            guard !draggingItems.isEmpty else { return }
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        private func draggingItem(for pasteboardItem: NSPasteboardItem) -> NSDraggingItem {
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let image = dragPreviewImage ?? viewModel?.icon ?? NSImage()
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: image.size),
                contents: image
            )
            return draggingItem
        }

        private func removeDraggedItemsFromShelf() {
            for item in draggedItems {
                ShelfStore.shared.remove(item)
            }
            ShelfSelection.shared.clear()
        }

        private func pasteboardItem(displayName: String) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(displayName, forType: .string)
            return pasteboardItem
        }

        private func pasteboardItem(for url: URL) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            if url.startAccessingSecurityScopedResource() {
                draggedURLs.append(url)
            }
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(url.path, forType: .string)
            return pasteboardItem
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if Preferences.shared.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.copy, .move, .generic]
            @unknown default:
                return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelection.shared.beginDrag()
            removeDraggedItemsFromShelf()
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            for url in draggedURLs { url.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}
```

- [x] **Step 2: Delete `DraggableClickHandler` from `ShelfItemView.swift`**

`ShelfItemView.swift` should now contain only:
- `import AppKit`, `import SwiftUI`
- `struct ShelfItemView: View` and its private helpers (`iconView`, `stackListButton`, `textView`, `backgroundView`, color/stroke helpers, `renderDragPreview()`).

The file should drop from 643 lines to roughly 165.

- [x] **Step 3: Regenerate the project & test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass.

- [ ] **Step 4: Manual smoke check**

Agent note: automated verification passed on 2026-05-15 with `./scripts/test.sh`
after `xcodegen generate` (47 Swift Testing tests). This manual GUI smoke check
still needs a real Finder drag/right-click pass.

Drag a single item out → Finder receives the file, shelf removes it.
Drag a multi-selection out → all files end up at the drop target.
Right-click an item → context menu appears.
Click the stack-list button on a stack → popover appears and dismisses on outside click.

- [x] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/Drag/ NotchShelf/Shelf/Views/ShelfItemView.swift NotchShelf.xcodeproj
git commit -m "refactor: extract DraggableClickHandler into Shelf/Views/Drag/"
```

---

## Phase 4 — Explicit state + ViewData

### Task 15: Introduce `ShelfItemViewData` and move presentation strings out of the domain model

**Background:** `ShelfItem.displayName` formats `"Folder (N)"` and reads `localizedNameKey` — pure presentation logic that belongs in the View layer per the MVVM playbook.

**Files:**
- Create: `NotchShelf/Shelf/State/ShelfItemViewData.swift`
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`
- Modify: `NotchShelf/Shelf/Models/ShelfItem.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`
- Modify: `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`
- Modify: `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`
- Modify: `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`
- Modify: `NotchShelfTests/ShelfItemTests.swift`

- [ ] **Step 1: Create `ShelfItemViewData.swift`**

```swift
import Foundation

/// Presentation-layer view of a `ShelfItem`. Built by `ShelfItemViewModel`, consumed
/// by views. Keeps formatting concerns out of the domain `ShelfItem`.
struct ShelfItemViewData: Equatable, Hashable {
    let id: UUID
    let displayName: String
    let isStack: Bool
    let stackCount: Int

    static func build(from item: ShelfItem) -> ShelfItemViewData {
        ShelfItemViewData(
            id: item.id,
            displayName: makeDisplayName(item),
            isStack: item.isStack,
            stackCount: item.stackCount
        )
    }

    private static func makeDisplayName(_ item: ShelfItem) -> String {
        guard let url = item.fileURL else { return "Unknown file" }
        if item.isStack {
            let folder = url.deletingLastPathComponent().lastPathComponent
            return "\(folder) (\(item.stackCount))"
        }
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
            ?? url.lastPathComponent
    }
}
```

- [ ] **Step 2: Remove `displayName` from `ShelfItem`**

In `NotchShelf/Shelf/Models/ShelfItem.swift`, delete this property:

```swift
    /// Finder-style display name, falling back to the last path component.
    var displayName: String { ... }
```

- [ ] **Step 3: Update `ShelfItemViewModel` to expose `viewData`**

Add `viewData` to `ShelfItemViewModel`:

```swift
@Published private(set) var item: ShelfItem
@Published private(set) var viewData: ShelfItemViewData
```

Initialize in `init`:

```swift
init(item: ShelfItem) {
    self.item = item
    self.viewData = ShelfItemViewData.build(from: item)
    loadThumbnail()
}
```

In `update(item:)`:

```swift
func update(item: ShelfItem) {
    guard self.item != item else { return }
    self.item = item
    self.viewData = ShelfItemViewData.build(from: item)
    thumbnail = nil
    loadThumbnail()
}
```

- [ ] **Step 4: Update callsites that used `item.displayName`**

In `NotchShelf/Shelf/Views/ShelfItemView.swift`:

`textView` body:
```swift
private var textView: some View {
    Text(viewModel.viewData.displayName)
        .font(.system(size: viewModel.viewData.isStack ? 10 : 12, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(viewModel.viewData.isStack ? 1 : 2)
        .truncationMode(.middle)
        .multilineTextAlignment(.center)
        .frame(height: viewModel.viewData.isStack ? 16 : 28, alignment: .top)
}
```

`renderDragPreview`:
```swift
private func renderDragPreview() async -> NSImage {
    let content = DragPreviewView(
        thumbnail: viewModel.thumbnail ?? viewModel.icon,
        displayName: viewModel.viewData.displayName
    )
    ...
}
```

In `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`, replace `dragItem.displayName` in the `pasteboardItem(displayName:)` callsite with a helper. The simplest fix is to bring `ShelfItemViewData.build` into the drag path:

```swift
if urls.isEmpty {
    let viewData = ShelfItemViewData.build(from: dragItem)
    if let pasteboardItem = pasteboardItem(displayName: viewData.displayName) {
        draggingItems.append(draggingItem(for: pasteboardItem))
    }
    continue
}
```

In `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`, the `title` derives from `url.lastPathComponent` already — no change needed there.

In `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`, the `title` field is informational only; leave as-is.

- [ ] **Step 5: Update `ShelfItem` tests**

If `ShelfItemTests.swift` references `displayName`, move those assertions to a new file `NotchShelfTests/ShelfItemViewDataTests.swift`:

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func viewDataFallsBackToLastPathComponent() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("hello.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)

    let viewData = ShelfItemViewData.build(from: item)

    #expect(viewData.displayName == "hello.txt" || viewData.displayName.hasPrefix("hello"))
    #expect(viewData.isStack == false)
}

@Test func viewDataStackFormatsAsFolderWithCount() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString + "_folder", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let a = dir.appendingPathComponent("a.txt")
    let b = dir.appendingPathComponent("b.txt")
    try "x".write(to: a, atomically: true, encoding: .utf8)
    try "y".write(to: b, atomically: true, encoding: .utf8)
    let bookmarks = [
        try Bookmark(url: a).data,
        try Bookmark(url: b).data
    ]
    let stack = ShelfItem(stackBookmarkData: bookmarks)

    let viewData = ShelfItemViewData.build(from: stack)

    #expect(viewData.isStack == true)
    #expect(viewData.stackCount == 2)
    #expect(viewData.displayName.contains("(2)"))
}
```

Delete corresponding `displayName` assertions from `ShelfItemTests.swift` if present.

- [ ] **Step 6: Regenerate and test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf NotchShelfTests NotchShelf.xcodeproj
git commit -m "refactor: extract presentation formatting into ShelfItemViewData"
```

---

### Task 16: Replace `items` + `isLoading` with `Loadable<[ShelfItem]>`

**Background:** Per MVVM playbook, prefer explicit state types over boolean combinations. Wraps load lifecycle in a single `enum`.

**Files:**
- Create: `NotchShelf/Shelf/State/Loadable.swift`
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Modify: `NotchShelf/App/ContentView.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfView.swift`
- Modify: `NotchShelfTests/ShelfStoreTests.swift`

- [ ] **Step 1: Create `Loadable.swift`**

```swift
import Foundation

/// Unified load-lifecycle state used by `ShelfStore`. Replaces parallel `items` +
/// `isLoading` flags so callers can pattern-match a single source of truth.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }
}

extension Loadable: Equatable where Value: Equatable {}
```

- [ ] **Step 2: Refactor `ShelfStore` to expose `state` while keeping the existing API**

Add a derived `state` property without removing `items`/`isLoading` outright — callers still depend on them. Append at the bottom of `ShelfStore`:

```swift
    /// Composite load state derived from `items` and `isLoading`.
    var state: Loadable<[ShelfItem]> {
        if isLoading && items.isEmpty { return .loading }
        if let error = lastError { return .failed(error) }
        return .loaded(items)
    }

    /// Most recent persistence error, set by `ShelfPersistenceService` failures.
    @Published private(set) var lastError: String?
```

Wire `lastError` to persistence: extend `ShelfPersistenceService.save` to return `Result`:

In `NotchShelf/Shelf/Services/ShelfPersistenceService.swift`:

```swift
@discardableResult
func save(_ items: [ShelfItem]) -> Result<Void, Error> {
    do {
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
        return .success(())
    } catch {
        NSLog("Failed to save shelf items: \(error.localizedDescription)")
        return .failure(error)
    }
}
```

Update `ShelfStore.flushPendingSave` and `schedulePersistenceSave` to propagate the error:

```swift
    private func schedulePersistenceSave() {
        saveTask?.cancel()
        let snapshot = items
        let persistence = self.persistence
        let debounce = saveDebounce
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let result = await Task.detached { persistence.save(snapshot) }.value
            if case .failure(let error) = result {
                self?.lastError = error.localizedDescription
            } else {
                self?.lastError = nil
            }
        }
    }

    func flushPendingSave() async {
        saveTask?.cancel()
        saveTask = nil
        let snapshot = items
        let result = await Task.detached { [persistence] in persistence.save(snapshot) }.value
        if case .failure(let error) = result {
            self.lastError = error.localizedDescription
        }
    }
```

- [ ] **Step 3: Add a test for the failure path**

In `ShelfStoreTests.swift`:

```swift
@MainActor @Test func storeRecordsLastErrorWhenPersistenceWriteFails() async throws {
    // Use a path that points to a non-existent parent so the write fails.
    let bogusDir = URL(fileURLWithPath: "/dev/null/cannot-create")
    let persistence = ShelfPersistenceService(directory: bogusDir)
    let store = ShelfStore(persistence: persistence)

    let a = try makeFileItem(named: "a.txt")
    store.add([a])
    await store.flushPendingSave()

    #expect(store.lastError != nil)
}
```

- [ ] **Step 4: Build & test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf NotchShelfTests NotchShelf.xcodeproj
git commit -m "feat: surface persistence errors via ShelfStore.lastError"
```

---

## Phase 5 — DI shim with protocols

> **Why:** Decouple ViewModels from `.shared` singletons so they can be unit-tested with fakes. Backwards-compatible — defaults still reach for `.shared`.

### Task 17: Introduce protocols for shared services

**Files:**
- Create: `NotchShelf/Shared/Protocols/Services.swift`
- Modify: `NotchShelf/Shared/Preferences.swift`
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Modify: `NotchShelf/Shelf/State/ShelfSelection.swift`

- [ ] **Step 1: Create the protocols file**

```bash
mkdir -p NotchShelf/Shared/Protocols
```

`NotchShelf/Shared/Protocols/Services.swift`:

```swift
import Foundation

/// Read/write access to a single boolean preference that controls drag semantics.
@MainActor
protocol PreferenceProviding: AnyObject {
    var copyOnDrag: Bool { get set }
}

/// Read-only view of the shelf's items, plus mutation helpers used by drag handlers
/// and the action service.
@MainActor
protocol ShelfStoring: AnyObject {
    var items: [ShelfItem] { get }
    func add(_ items: [ShelfItem])
    func remove(_ item: ShelfItem)
    func remove(bookmarkData: Data, from item: ShelfItem)
    func resolveFileURLs(for item: ShelfItem) -> [URL]
}

/// Multi-selection state.
@MainActor
protocol SelectionStoring: AnyObject {
    var selectedIDs: Set<UUID> { get }
    var isDragging: Bool { get }
    func isSelected(_ id: UUID) -> Bool
    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem]
    func selectSingle(_ item: ShelfItem)
    func toggle(_ item: ShelfItem)
    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem])
    func clear()
    func beginDrag()
    func endDrag()
}
```

- [ ] **Step 2: Conform the singletons**

In `NotchShelf/Shared/Preferences.swift`:

```swift
import Foundation

final class Preferences: PreferenceProviding, @unchecked Sendable {
    // ...existing body unchanged...
}
```

Note: `PreferenceProviding` is `@MainActor`. Because `Preferences` is currently accessed from non-main contexts, mark it as such instead:

```swift
@MainActor
final class Preferences: PreferenceProviding {
    static let shared = Preferences()

    private let defaults: UserDefaults
    private enum Key {
        static let copyOnDrag = "copyOnDrag"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var copyOnDrag: Bool {
        get { defaults.bool(forKey: Key.copyOnDrag) }
        set { defaults.set(newValue, forKey: Key.copyOnDrag) }
    }
}
```

(Drop `@unchecked Sendable` — the class is now `@MainActor` so it does not need to be `Sendable`. If a non-main caller appears, this surfaces at compile-time.)

In `NotchShelf/Shelf/State/ShelfStore.swift`, add conformance:

```swift
@MainActor
final class ShelfStore: ObservableObject, ShelfStoring {
    // ...
}
```

The current public API already matches `ShelfStoring`. `items` is `@Published private(set) var items: [ShelfItem]` — the protocol's read-only `get` is satisfied.

In `NotchShelf/Shelf/State/ShelfSelection.swift`:

```swift
@MainActor
final class ShelfSelection: ObservableObject, SelectionStoring {
    // ...
}
```

`selectedIDs` is already `@Published private(set)` — read-only access works.

- [ ] **Step 3: Build & test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass. If a compiler error appears because a non-main caller touches `Preferences.shared`, that callsite needs to be moved into a `@MainActor` context — those are exactly the call paths the audit flagged.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf NotchShelf.xcodeproj
git commit -m "refactor: introduce PreferenceProviding/ShelfStoring/SelectionStoring protocols"
```

---

### Task 18: Inject `PreferenceProviding` into drag-source views

**Background:** `Preferences.shared.copyOnDrag` is read from inside `NSDraggingSource` callbacks in both `StackFileDragView` and `DraggableClickView`. With the protocol, the singleton lookup is now a constructor injection point.

**Files:**
- Modify: `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`
- Modify: `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`

- [ ] **Step 1: Pass `PreferenceProviding` through `StackFileDragHandler` → `StackFileDragView`**

```swift
struct StackFileDragHandler: NSViewRepresentable {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let previewImage: NSImage
    var preferences: PreferenceProviding = Preferences.shared

    func makeNSView(context: Context) -> StackFileDragView {
        let view = StackFileDragView()
        view.sourceItem = sourceItem
        view.bookmarkData = entry.bookmarkData
        view.title = entry.title
        view.previewImage = previewImage
        view.preferences = preferences
        return view
    }

    func updateNSView(_ nsView: StackFileDragView, context: Context) {
        nsView.sourceItem = sourceItem
        nsView.bookmarkData = entry.bookmarkData
        nsView.title = entry.title
        nsView.previewImage = previewImage
        nsView.preferences = preferences
    }

    final class StackFileDragView: NSView, NSDraggingSource {
        var sourceItem: ShelfItem?
        var bookmarkData = Data()
        var title = ""
        var previewImage = NSImage()
        var preferences: PreferenceProviding = Preferences.shared
        // ...existing fields unchanged...

        // Replace the direct singleton reference:
        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if preferences.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.copy, .move, .generic]
            @unknown default:
                return [.copy]
            }
        }
        // ...rest unchanged...
    }
}
```

- [ ] **Step 2: Mirror the change in `DraggableClickHandler`**

```swift
struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    @Binding var cachedPreviewImage: NSImage?
    let onClick: (NSEvent, NSView) -> Void
    let onRightClick: (NSEvent, NSView) -> Void
    var preferences: PreferenceProviding = Preferences.shared

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.viewModel = viewModel
        view.dragPreviewImage = cachedPreviewImage ?? viewModel.icon
        view.onClick = onClick
        view.onRightClick = onRightClick
        view.preferences = preferences
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
        nsView.preferences = preferences
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem?
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?
        var preferences: PreferenceProviding = Preferences.shared
        // ...existing fields unchanged...

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if preferences.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.copy, .move, .generic]
            @unknown default:
                return [.copy]
            }
        }
        // ...rest unchanged...
    }
}
```

- [ ] **Step 3: Build & test**

```bash
./scripts/test.sh
```
Expected: all tests pass.

- [ ] **Step 4: Manual smoke check**

Toggle `copyOnDrag` in Preferences, drag a file out, confirm copy. Toggle off, confirm copy/move behavior returns. Repeat for stack popover row drag.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/Drag/
git commit -m "refactor: inject PreferenceProviding into drag-source views"
```

---

### Task 19: Inject `ShelfStoring` + `SelectionStoring` into `ShelfItemViewModel`

**Background:** `ShelfItemViewModel` currently reads `ShelfStore.shared` and `ShelfSelection.shared` directly inside `handleDoubleClick`, `handleRightClick`, and `handleClick`. With the protocols ready, switch to constructor injection.

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`
- Modify: `NotchShelfTests/ShelfItemViewModelTests.swift`

- [ ] **Step 1: Update `ShelfItemViewModel` constructor**

```swift
@MainActor
final class ShelfItemViewModel: ObservableObject {
    @Published private(set) var item: ShelfItem
    @Published private(set) var viewData: ShelfItemViewData
    @Published var thumbnail: NSImage?
    @Published var isDropTargeted: Bool = false

    private let store: ShelfStoring
    private let selection: SelectionStoring
    private var thumbnailTask: Task<Void, Never>?

    init(
        item: ShelfItem,
        store: ShelfStoring = ShelfStore.shared,
        selection: SelectionStoring = ShelfSelection.shared
    ) {
        self.item = item
        self.viewData = ShelfItemViewData.build(from: item)
        self.store = store
        self.selection = selection
        loadThumbnail()
    }

    // ...keep `update(item:)`, `icon`, `loadThumbnail`, `deinit` unchanged...

    var isSelected: Bool { selection.isSelected(item.id) }

    func handleClick(event: NSEvent, view: NSView) {
        let flags = event.modifierFlags
        if flags.contains(.shift) {
            selection.shiftSelect(to: item, in: store.items)
        } else if flags.contains(.command) {
            selection.toggle(item)
        } else if flags.contains(.control) {
            handleRightClick(event: event, view: view)
            return
        } else if !selection.isSelected(item.id) {
            selection.selectSingle(item)
        }
        if event.clickCount == 2 { handleDoubleClick() }
    }

    func handleDoubleClick() {
        for selectedItem in selection.selectedItems(in: store.items) {
            ShelfActionService.open(selectedItem)
        }
    }

    func handleRightClick(event: NSEvent, view: NSView) {
        if !selection.isSelected(item.id) { selection.selectSingle(item) }
        let menu = NSMenu()
        addItem(to: menu, title: "Open") { ShelfActionService.open(self.item) }
        addItem(to: menu, title: "Show in Finder") { ShelfActionService.reveal(self.item) }
        addItem(to: menu, title: "Copy Path") { ShelfActionService.copyPath(self.item) }
        menu.addItem(.separator())
        addItem(to: menu, title: "Remove from Shelf") {
            for selectedItem in self.selection.selectedItems(in: self.store.items) {
                ShelfActionService.remove(selectedItem)
            }
        }
        menu.popUp(positioning: nil, at: event.locationInWindow, in: view)
    }
}
```

- [ ] **Step 2: Add a tested behavior using fakes**

In `NotchShelfTests/ShelfItemViewModelTests.swift`, add:

```swift
import Testing
import AppKit
@testable import NotchShelf

@MainActor
final class FakeShelfStore: ShelfStoring {
    var items: [ShelfItem] = []
    func add(_ items: [ShelfItem]) { self.items.append(contentsOf: items) }
    func remove(_ item: ShelfItem) { items.removeAll { $0.id == item.id } }
    func remove(bookmarkData: Data, from item: ShelfItem) {}
    func resolveFileURLs(for item: ShelfItem) -> [URL] { [] }
}

@MainActor
final class FakeSelection: SelectionStoring {
    var selectedIDs: Set<UUID> = []
    var isDragging: Bool = false
    var lastShiftSelectAnchor: UUID?

    func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }
    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }
    func selectSingle(_ item: ShelfItem) { selectedIDs = [item.id] }
    func toggle(_ item: ShelfItem) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else { selectedIDs.insert(item.id) }
    }
    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem]) {
        lastShiftSelectAnchor = item.id
    }
    func clear() { selectedIDs.removeAll() }
    func beginDrag() { isDragging = true }
    func endDrag() { isDragging = false }
}

@MainActor @Test func viewModelUsesInjectedDependencies() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("a.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)

    let store = FakeShelfStore()
    store.items = [item]
    let selection = FakeSelection()

    let viewModel = ShelfItemViewModel(item: item, store: store, selection: selection)

    #expect(viewModel.isSelected == false)
    selection.selectSingle(item)
    #expect(viewModel.isSelected == true)
}
```

- [ ] **Step 3: Build & test**

```bash
xcodegen generate
./scripts/test.sh
```
Expected: all tests pass including the new injection test.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf NotchShelfTests NotchShelf.xcodeproj
git commit -m "refactor: inject ShelfStoring and SelectionStoring into ShelfItemViewModel"
```

---

## Closeout

- [ ] **Final step: full regression sweep**

Run:
```bash
./scripts/test.sh
xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build
./scripts/run.sh
```

Smoke-test in order:
1. Drag two files from Finder over the notch → shelf expands → drop succeeds.
2. Drag a folder of three files → stack appears with `(3)` suffix.
3. Click stack-list button → popover lists three rows.
4. Drag one row out → file leaves the stack, count decrements.
5. Right-click an item → menu opens, each action works.
6. Open Preferences, toggle `copyOnDrag` → drag-out becomes copy-only.
7. Quit app, relaunch → shelf state persists.
8. Delete a file from disk while app is closed, relaunch → invalid item is cleaned up.

If all eight pass, the audit fix series is complete.

---

## Self-Review Notes

**Coverage of the audit findings:**
- K1 (PreferencesView desync): Task 1 ✓
- K2 (DI): Tasks 17-19 ✓
- K3 (Split `ShelfItemView`): Tasks 12-14 ✓
- K4 (Force-unwraps): Task 2 ✓ (with follow-up in Tasks 13-14 keeping the optional types)
- K5 (Parallel validation): Task 9 ✓
- K6 (Debounce save): Task 7 ✓
- I1 (Cancel debounce): Task 8 ✓
- I2 (Drop unnecessary Task): Task 6 ✓
- I3 (ViewData): Task 15 ✓
- I4 (Cache identityKey): Task 10 ✓
- I5 (`Preferences` Sendable): folded into Task 17 (`@MainActor` replaces `@unchecked Sendable`)
- I6 (Loadable): Task 16 ✓
- I8 (Cleanup placement): Task 4 ✓
- I9 (`DragMonitor` lifecycle): Task 5 ✓
- I11 (Cancel `load` task): Task 11 ✓
- D6 (Dead code): Task 3 ✓

Not covered (intentionally — diminishing returns):
- I7 `PreferencesWindowController` singleton — works fine, low ROI to refactor.
- I10 `MenuActionTarget` — opaque but functional; revisit if menu logic grows.
- D1-D5, D7-D10 — cosmetic; leave for the next pass.

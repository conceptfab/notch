import Foundation

/// The shelf's central state: the ordered list of items, persistence, and bookmark
/// lifecycle (refreshing stale bookmarks, pruning dead ones).
@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    private let persistence: ShelfPersistenceService

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { schedulePersistenceSave() }
    }

    @Published var isLoading: Bool = false

    private var saveTask: Task<Void, Never>?
    private var inflightWrite: Task<Void, Never>?
    private let saveDebounce: Duration = .milliseconds(200)

    var isEmpty: Bool { items.isEmpty }

    /// Deferred bookmark refreshes, applied off the current run loop turn so we never
    /// mutate `items` while SwiftUI is reading it.
    private var pendingBookmarkUpdates: [ShelfItem.ID: Data] = [:]
    private var updateTask: Task<Void, Never>?

    init(persistence: ShelfPersistenceService = .shared) {
        self.persistence = persistence
        let loaded = persistence.load()
        // Assigning to the backing storage bypasses didSet on initial load.
        _items = Published(initialValue: loaded)
    }

    /// Appends new items, skipping any whose `identityKey` already exists.
    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        var seen = Set(merged.map(\.identityKey))
        for item in newItems {
            if let folderKey = item.sourceFolderKey,
               let idx = merged.firstIndex(where: {
                   $0.sourceFolderKey == folderKey && ($0.isStack || item.isStack)
               }) {
                let updated = merged[idx].merging(with: item)
                seen.remove(merged[idx].identityKey)
                merged[idx] = updated
                seen.insert(updated.identityKey)
                continue
            }
            guard !seen.contains(item.identityKey) else { continue }
            merged.append(item)
            seen.insert(item.identityKey)
        }
        items = merged
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func remove(bookmarkData: Data, from item: ShelfItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var remaining = items[idx].allBookmarkData
        remaining.removeAll { $0 == bookmarkData }
        switch remaining.count {
        case 0:
            items.remove(at: idx)
        case 1:
            items[idx] = ShelfItem(id: item.id, bookmarkData: remaining[0])
        default:
            items[idx] = ShelfItem(id: item.id, stackBookmarkData: remaining)
        }
    }

    /// Immediately replaces an item's bookmark (used for user-initiated actions).
    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].bookmarkData = bookmark
    }

    /// Queues a stale-bookmark refresh to be applied after the current update cycle.
    private func scheduleDeferredBookmarkUpdate(for item: ShelfItem, bookmark: Data) {
        pendingBookmarkUpdates[item.id] = bookmark
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            for (id, data) in self.pendingBookmarkUpdates {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx].bookmarkData = data
                }
            }
            self.pendingBookmarkUpdates.removeAll()
        }
    }

    /// Loads dropped providers into the shelf asynchronously.
    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        isLoading = true
        // Wrap in a nonisolated(unsafe) box so Swift 6 does not flag the
        // NSItemProvider (non-Sendable) transfer across the actor boundary.
        // NSItemProvider is thread-safe in practice; the providers are only
        // read inside the Task, never mutated after capture.
        nonisolated(unsafe) let sendableProviders = providers
        Task { @MainActor [weak self] in
            let dropped = await ShelfDropService.items(from: sendableProviders)
            self?.add(dropped)
            self?.isLoading = false
        }
    }

    /// Removes items whose bookmark no longer resolves to an existing file.
    /// Items added while validation is in flight are preserved.
    func cleanupInvalidItems() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = self.items
            var validIDs: Set<ShelfItem.ID> = []
            for item in snapshot {
                if await Bookmark(data: item.bookmarkData).validate() {
                    validIDs.insert(item.id)
                }
            }
            let snapshotIDs = Set(snapshot.map(\.id))
            // Keep validated items, plus anything added since the snapshot.
            self.items = self.items.filter { validIDs.contains($0.id) || !snapshotIDs.contains($0.id) }
        }
    }

    /// Resolves an item's URL, scheduling a deferred refresh if the bookmark was stale.
    func resolveFileURL(for item: ShelfItem) -> URL? {
        let result = Bookmark(data: item.bookmarkData).resolve()
        if let refreshed = result.refreshedData, refreshed != item.bookmarkData {
            scheduleDeferredBookmarkUpdate(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveFileURLs(for item: ShelfItem) -> [URL] {
        item.allBookmarkData.compactMap { Bookmark(data: $0).resolveURL() }
    }

    private func schedulePersistenceSave() {
        saveTask?.cancel()
        let snapshot = items
        let persistence = self.persistence
        let debounce = saveDebounce
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.inflightWrite?.value
            let write = Task.detached { persistence.save(snapshot) }
            self?.inflightWrite = write
            await write.value
            if self?.inflightWrite == write { self?.inflightWrite = nil }
        }
    }

    /// Flushes any pending debounced save asynchronously. Intended for tests.
    /// For app termination, see `flushPendingSaveSync()`.
    func flushPendingSave() async {
        saveTask?.cancel()
        saveTask = nil
        await inflightWrite?.value
        let snapshot = items
        let write = Task.detached { [persistence] in persistence.save(snapshot) }
        inflightWrite = write
        await write.value
        if inflightWrite == write { inflightWrite = nil }
    }

    /// Synchronously flushes the most recent shelf state to disk. Intended only for
    /// `applicationWillTerminate`, where a brief main-thread block at quit is acceptable.
    /// Must be called from the main actor.
    nonisolated func flushPendingSaveSync() {
        MainActor.assumeIsolated {
            saveTask?.cancel()
            saveTask = nil
            // Wait inline for any in-flight detached write to settle so the
            // synchronous save below is unambiguously the last to land on disk.
            if let inflight = inflightWrite {
                let semaphore = DispatchSemaphore(value: 0)
                Task.detached {
                    await inflight.value
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 2.0)
                inflightWrite = nil
            }
            persistence.save(items)
        }
    }
}

import Foundation

/// The shelf's central state: the ordered list of items, persistence, and bookmark
/// lifecycle (refreshing stale bookmarks, pruning dead ones).
@MainActor
final class ShelfStore: ObservableObject, ShelfStoring {
    static let shared = ShelfStore()

    private let persistence: ShelfPersistenceService

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { schedulePersistenceSave() }
    }

    @Published var isLoading: Bool = false
    @Published private(set) var lastError: String?

    private var saveTask: Task<Void, Never>?
    private var inflightWrite: Task<String?, Never>?
    private var loadTask: Task<Void, Never>?
    private let saveDebounce: Duration = .milliseconds(200)

    var isEmpty: Bool { items.isEmpty }

    var totalFileCount: Int {
        items.reduce(0) { $0 + $1.stackCount }
    }

    /// Composite load state derived from `items` and `isLoading`.
    var state: Loadable<[ShelfItem]> {
        if isLoading && items.isEmpty { return .loading }
        if let lastError { return .failed(lastError) }
        return .loaded(items)
    }

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
        // Pre-compute identity keys so we resolve each bookmark at most once per add().
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

    /// Loads dropped providers into the shelf asynchronously. Cancels any in-flight load.
    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        loadTask?.cancel()
        isLoading = true
        // Wrap in a nonisolated(unsafe) box so Swift 6 does not flag the
        // NSItemProvider (non-Sendable) transfer across the actor boundary.
        // NSItemProvider is thread-safe in practice; the providers are only
        // read inside the Task, never mutated after capture.
        nonisolated(unsafe) let sendableProviders = providers
        loadTask = Task { @MainActor [weak self] in
            let dropped = await ShelfDropService.items(from: sendableProviders)
            guard !Task.isCancelled else { return }
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
            if let inflightWrite = self?.inflightWrite {
                _ = await inflightWrite.value
            }
            let write = Task.detached {
                persistence.save(snapshot).errorMessage
            }
            self?.inflightWrite = write
            self?.lastError = await write.value
            if self?.inflightWrite == write { self?.inflightWrite = nil }
        }
    }

    /// Flushes any pending debounced save asynchronously. Intended for tests.
    /// For app termination, see `flushPendingSaveSync()`.
    func flushPendingSave() async {
        saveTask?.cancel()
        saveTask = nil
        if let inflightWrite {
            _ = await inflightWrite.value
        }
        let snapshot = items
        let write = Task.detached { [persistence] in
            persistence.save(snapshot).errorMessage
        }
        inflightWrite = write
        lastError = await write.value
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
                    _ = await inflight.value
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 2.0)
                inflightWrite = nil
            }
            lastError = persistence.save(items).errorMessage
        }
    }
}

private extension Result where Success == Void, Failure == Error {
    var errorMessage: String? {
        if case .failure(let error) = self {
            return error.localizedDescription
        }
        return nil
    }
}

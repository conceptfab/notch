import Foundation

/// The shelf's central state: the ordered list of items, persistence, and bookmark
/// lifecycle (refreshing stale bookmarks, pruning dead ones).
@MainActor
final class ShelfStore: ObservableObject, ShelfStoring {
    static let shared = ShelfStore()
    static let defaultSlotCount = 5

    private let persistence: ShelfPersistenceService

    @Published private(set) var slots: [ShelfSlot] = [] {
        didSet { schedulePersistenceSave() }
    }

    @Published var isLoading: Bool = false
    @Published private(set) var lastError: String?

    private var saveTask: Task<Void, Never>?
    private var inflightWrite: Task<String?, Never>?
    private var loadTask: Task<Void, Never>?
    private let saveDebounce: Duration = .milliseconds(200)

    var items: [ShelfItem] { slots.compactMap(\.item) }

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
        let loaded = Self.paddedSlots(persistence.loadSlots())
        // Assigning to the backing storage bypasses didSet on initial load.
        _slots = Published(initialValue: loaded)
    }

    /// Appends new items, skipping any whose `identityKey` already exists.
    func add(_ newItems: [ShelfItem]) {
        add(newItems, atSlot: nil)
    }

    func add(_ newItems: [ShelfItem], atSlot slotIndex: Int?) {
        guard !newItems.isEmpty else { return }
        var mergedSlots = Self.paddedSlots(slots)
        // Pre-compute identity keys so we resolve each bookmark at most once per add().
        var keys: [ShelfItem.ID: String] = [:]
        for item in mergedSlots.compactMap(\.item) { keys[item.id] = item.identityKey }
        var seen = Set(keys.values)
        var nextSlotIndex = slotIndex ?? firstEmptySlotIndex(in: mergedSlots) ?? mergedSlots.count

        for item in newItems {
            let folderKey = item.sourceFolderKey
            if let folderKey,
               let idx = mergedSlots.firstIndex(where: {
                   guard let existing = $0.item else { return false }
                   return existing.sourceFolderKey == folderKey && (existing.isStack || item.isStack)
               }) {
                guard let existing = mergedSlots[idx].item else { continue }
                let updated = existing.merging(with: item)
                if let oldKey = keys[existing.id] {
                    seen.remove(oldKey)
                }
                mergedSlots[idx].item = updated
                let newKey = updated.identityKey
                keys[updated.id] = newKey
                seen.insert(newKey)
                continue
            }
            let key = item.identityKey
            guard !seen.contains(key) else { continue }
            nextSlotIndex = place(item, in: &mergedSlots, startingAt: nextSlotIndex)
            keys[item.id] = key
            seen.insert(key)
        }
        slots = Self.paddedSlots(mergedSlots)
    }

    func remove(_ item: ShelfItem) {
        var updated = slots
        for idx in updated.indices where updated[idx].item?.id == item.id {
            updated[idx].item = nil
        }
        slots = Self.paddedSlots(updated)
    }

    func remove(bookmarkData: Data, from item: ShelfItem) {
        guard let idx = slots.firstIndex(where: { $0.item?.id == item.id }),
              let slotItem = slots[idx].item else { return }
        var remaining = slotItem.allBookmarkData
        remaining.removeAll { $0 == bookmarkData }
        var updated = slots
        switch remaining.count {
        case 0:
            updated[idx].item = nil
        case 1:
            updated[idx].item = ShelfItem(id: item.id, bookmarkData: remaining[0])
        default:
            updated[idx].item = ShelfItem(id: item.id, stackBookmarkData: remaining)
        }
        slots = Self.paddedSlots(updated)
    }

    /// Immediately replaces an item's bookmark (used for user-initiated actions).
    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = slots.firstIndex(where: { $0.item?.id == item.id }) else { return }
        slots[idx].item?.bookmarkData = bookmark
    }

    /// Queues a stale-bookmark refresh to be applied after the current update cycle.
    private func scheduleDeferredBookmarkUpdate(for item: ShelfItem, bookmark: Data) {
        pendingBookmarkUpdates[item.id] = bookmark
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            for (id, data) in self.pendingBookmarkUpdates {
                if let idx = self.slots.firstIndex(where: { $0.item?.id == id }) {
                    self.slots[idx].item?.bookmarkData = data
                }
            }
            self.pendingBookmarkUpdates.removeAll()
        }
    }

    /// Loads dropped providers into the shelf asynchronously. Cancels any in-flight load.
    func load(_ providers: [NSItemProvider]) {
        load(providers, intoSlot: nil)
    }

    func load(_ providers: [NSItemProvider], intoSlot slotIndex: Int?) {
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
            self?.add(dropped, atSlot: slotIndex)
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
            self.slots = Self.paddedSlots(self.slots.map { slot in
                guard let item = slot.item else { return slot }
                if validIDs.contains(item.id) || !snapshotIDs.contains(item.id) {
                    return slot
                }
                return ShelfSlot(id: slot.id)
            })
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
        let snapshot = slots
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
        let snapshot = slots
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
            lastError = persistence.save(slots).errorMessage
        }
    }

    private static func paddedSlots(_ slots: [ShelfSlot]) -> [ShelfSlot] {
        guard slots.count < defaultSlotCount else { return slots }
        return slots + (slots.count..<defaultSlotCount).map { _ in ShelfSlot() }
    }

    private func firstEmptySlotIndex(in slots: [ShelfSlot]) -> Int? {
        slots.firstIndex { $0.item == nil }
    }

    private func place(_ item: ShelfItem, in slots: inout [ShelfSlot], startingAt startIndex: Int) -> Int {
        if startIndex >= slots.count {
            slots.append(ShelfSlot(item: item))
            return slots.count
        }
        if let index = slots.indices.dropFirst(startIndex).first(where: { slots[$0].item == nil }) {
            slots[index].item = item
            return index + 1
        } else {
            slots.append(ShelfSlot(item: item))
            return slots.count
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

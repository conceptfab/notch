import Foundation

/// Pure policy for how many slots the shelf should expose. Extracted from
/// `ShelfStore` so it can be unit-tested without UserDefaults or persistence.
enum SlotCountPolicy {
    /// `filledItems`: how many slots currently hold a `ShelfItem`.
    /// `currentVisible`: how many slots are presently rendered.
    /// `baseSlotCount`: user-configured slots in the first row.
    /// `maxAdditionalRows`: user-configured extra full rows that may appear.
    static func visibleSlotCount(
        filledItems: Int,
        currentVisible: Int,
        baseSlotCount: Int,
        maxAdditionalRows: Int
    ) -> Int {
        let rowCapacity = Swift.max(baseSlotCount, 1)
        let maximumRows = 1 + Swift.max(maxAdditionalRows, 0)
        let filledRows = Int(ceil(Double(Swift.max(filledItems, 0)) / Double(rowCapacity)))
        let targetRows = Swift.min(Swift.max(filledRows, 1), maximumRows)
        return targetRows * rowCapacity
    }
}

/// The shelf's central state: the ordered list of items, persistence, and bookmark
/// lifecycle (refreshing stale bookmarks, pruning dead ones).
@MainActor
final class ShelfStore: ObservableObject, ShelfStoring {
    static let shared = ShelfStore()
    static let defaultSlotCount = ShelfMetrics.defaultSlotCount

    private let persistence: ShelfPersistenceService
    private let defaults: UserDefaults

    @Published private(set) var slots: [ShelfSlot] = [] {
        didSet { schedulePersistenceSave() }
    }

    @Published var isLoading: Bool = false
    @Published private(set) var lastError: String?

    private var saveTask: Task<Void, Never>?
    private var inflightWrite: Task<String?, Never>?
    private var loadTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private let saveDebounce: Duration = .milliseconds(200)

    var items: [ShelfItem] { slots.compactMap(\.item) }

    var totalFileCount: Int {
        items.reduce(0) { $0 + $1.stackCount }
    }

    private var baseSlotCount: Int {
        ShelfMetrics.normalizedSlotCount(defaults.integer(forKey: UserDefaultsKey.minSlotCount))
    }

    private var maximumAdditionalRows: Int {
        ShelfMetrics.normalizedAdditionalRowCount(
            defaults.integer(forKey: UserDefaultsKey.maxSlotCount),
            baseSlotCount: baseSlotCount
        )
    }

    /// The number of slots the UI should render right now.
    var visibleSlotCount: Int {
        targetSlotCount(for: items.count, currentVisible: slots.count)
    }

    var visibleSlots: [ShelfSlot] {
        Self.paddedSlots(slots, target: visibleSlotCount)
    }

    /// Deferred bookmark refreshes, applied off the current run loop turn so we never
    /// mutate `items` while SwiftUI is reading it.
    private var pendingBookmarkUpdates: [ShelfItem.ID: Data] = [:]
    private var updateTask: Task<Void, Never>?

    init(persistence: ShelfPersistenceService = .shared, defaults: UserDefaults = .standard) {
        self.persistence = persistence
        self.defaults = defaults
        let raw = persistence.loadSlots()
        let baseSlotCount = ShelfMetrics.normalizedSlotCount(defaults.integer(forKey: UserDefaultsKey.minSlotCount))
        let maxAdditionalRows = ShelfMetrics.normalizedAdditionalRowCount(
            defaults.integer(forKey: UserDefaultsKey.maxSlotCount),
            baseSlotCount: baseSlotCount
        )
        let target = SlotCountPolicy.visibleSlotCount(
            filledItems: raw.compactMap(\.item).count,
            currentVisible: raw.count,
            baseSlotCount: baseSlotCount,
            maxAdditionalRows: maxAdditionalRows
        )
        let loaded = Self.paddedSlots(raw, target: target)
        // Assigning to the backing storage bypasses didSet on initial load.
        _slots = Published(initialValue: loaded)
    }

    /// Appends new items, skipping any whose `identityKey` already exists.
    func add(_ newItems: [ShelfItem]) {
        add(newItems, atSlot: nil)
    }

    func add(_ newItems: [ShelfItem], atSlot slotIndex: Int?) {
        guard !newItems.isEmpty else { return }
        var mergedSlots = reslot(slots)
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
        slots = reslot(mergedSlots)
    }

    func remove(_ item: ShelfItem) {
        var updated = slots
        for idx in updated.indices where updated[idx].item?.id == item.id {
            updated[idx].item = nil
        }
        slots = reslot(updated)
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
        slots = reslot(updated)
    }

    func setKeepsItemAfterExternalDrop(_ keepsItem: Bool, forSlotID slotID: ShelfSlot.ID) {
        guard let index = slots.firstIndex(where: { $0.id == slotID && $0.item != nil }) else {
            return
        }
        var updated = slots
        updated[index].keepsItemAfterExternalDrop = keepsItem
        slots = updated
    }

    func toggleKeepsItemAfterExternalDrop(forSlotID slotID: ShelfSlot.ID) {
        guard let slot = slots.first(where: { $0.id == slotID }) else { return }
        setKeepsItemAfterExternalDrop(!slot.keepsItemAfterExternalDrop, forSlotID: slotID)
    }

    func keepsItemAfterExternalDrop(_ item: ShelfItem) -> Bool {
        slots.first { $0.item?.id == item.id }?.keepsItemAfterExternalDrop ?? false
    }

    /// Empties every slot. Persistence flushes via the existing `slots` didSet
    /// debounced save pipeline.
    func clearAll() {
        slots = reslot(slots.map { ShelfSlot(id: $0.id) })
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
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = self.items
            let validIDs = await Self.validateInParallel(snapshot)
            guard !Task.isCancelled else { return }
            let snapshotIDs = Set(snapshot.map(\.id))
            // Keep validated items, plus anything added since the snapshot.
            self.slots = self.reslot(self.slots.map { slot in
                guard let item = slot.item else { return slot }
                if validIDs.contains(item.id) || !snapshotIDs.contains(item.id) {
                    return slot
                }
                return ShelfSlot(id: slot.id)
            })
            self.cleanupTask = nil
        }
    }

    private static func validateInParallel(_ snapshot: [ShelfItem]) async -> Set<ShelfItem.ID> {
        let maxConcurrency = 8
        return await withTaskGroup(of: (ShelfItem.ID, Bool).self) { group in
            var iterator = snapshot.makeIterator()
            var inFlight = 0

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
        let persistence = self.persistence
        let debounce = saveDebounce
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            if let inflightWrite = self.inflightWrite {
                _ = await inflightWrite.value
            }
            let snapshot = self.slots
            let write = Task.detached {
                persistence.save(snapshot).errorMessage
            }
            self.inflightWrite = write
            self.lastError = await write.value
            if self.inflightWrite == write { self.inflightWrite = nil }
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
            cleanupTask?.cancel()
            let hadSaveTask = saveTask != nil
            saveTask?.cancel()
            saveTask = nil
            var shouldWriteSynchronously = hadSaveTask
            if let inflight = inflightWrite {
                let semaphore = DispatchSemaphore(value: 0)
                Task.detached {
                    _ = await inflight.value
                    semaphore.signal()
                }
                let result = semaphore.wait(timeout: .now() + 0.5)
                if result == .timedOut {
                    AppLogger.shelf.error("flushPendingSaveSync: in-flight write did not settle within 500ms; falling through to synchronous save")
                    shouldWriteSynchronously = true
                }
                inflightWrite = nil
            }
            if shouldWriteSynchronously {
                lastError = persistence.save(slots).errorMessage
            }
        }
    }

    private static func paddedSlots(_ slots: [ShelfSlot], target: Int) -> [ShelfSlot] {
        let target = Swift.max(target, 1)
        if slots.count < target {
            return slots + (slots.count..<target).map { _ in ShelfSlot() }
        }
        if slots.count == target { return slots }

        var visible = Array(slots.prefix(target))
        for overflowItem in slots.dropFirst(target).compactMap(\.item) {
            if let index = visible.firstIndex(where: { $0.item == nil }) {
                visible[index].item = overflowItem
            } else {
                visible.append(ShelfSlot(item: overflowItem))
            }
        }
        return visible
    }

    private func targetSlotCount(for filled: Int, currentVisible: Int) -> Int {
        SlotCountPolicy.visibleSlotCount(
            filledItems: filled,
            currentVisible: currentVisible,
            baseSlotCount: baseSlotCount,
            maxAdditionalRows: maximumAdditionalRows
        )
    }

    private func reslot(_ next: [ShelfSlot]) -> [ShelfSlot] {
        let target = targetSlotCount(
            for: next.compactMap(\.item).count,
            currentVisible: next.count
        )
        return Self.paddedSlots(next, target: target)
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

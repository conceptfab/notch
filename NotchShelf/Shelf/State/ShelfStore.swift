import Combine
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
        didSet {
            guard slots != oldValue else { return }
            schedulePersistenceSave()
        }
    }

    /// Test hook: number of times a debounced persistence save was scheduled.
    private(set) var scheduledSaveCount = 0

    @Published private(set) var lastError: String?
    /// Slots per row, mirrored from preferences so layout re-renders when only the
    /// column count changes (the slot total can stay the same).
    @Published private(set) var columnCount: Int

    private var saveTask: Task<Void, Never>?
    private var inflightWrite: Task<String?, Never>?
    private var loadTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var defaultsObserver: AnyCancellable?
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

    var rowCount: Int {
        Swift.max(Int(ceil(Double(visibleSlotCount) / Double(Swift.max(columnCount, 1)))), 1)
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
        _columnCount = Published(initialValue: baseSlotCount)

        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.applySlotPreferences() }
            }
    }

    /// Re-pads the stored slots when the slot preferences change, so placeholder
    /// slots keep stable IDs instead of being minted on every `visibleSlots` read.
    func applySlotPreferences() {
        let columns = baseSlotCount
        if columnCount != columns { columnCount = columns }
        let next = reslot(slots)
        if next != slots { slots = next }
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
            updated[idx] = ShelfSlot(id: updated[idx].id)
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
            updated[idx] = ShelfSlot(id: updated[idx].id)
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

    /// Loads dropped providers into the shelf asynchronously. Drops are applied in order;
    /// a new drop never discards one that is still loading.
    func load(_ providers: [NSItemProvider]) {
        load(providers, intoSlot: nil)
    }

    func load(_ providers: [NSItemProvider], intoSlot slotIndex: Int?) {
        guard !providers.isEmpty else { return }
        let previousLoad = loadTask
        // Wrap in a nonisolated(unsafe) box so Swift 6 does not flag the
        // NSItemProvider (non-Sendable) transfer across the actor boundary.
        // NSItemProvider is thread-safe in practice; the providers are only
        // read inside the Task, never mutated after capture.
        nonisolated(unsafe) let sendableProviders = providers
        loadTask = Task { @MainActor [weak self] in
            let dropped = await ShelfDropService.items(from: sendableProviders)
            await previousLoad?.value
            self?.add(dropped, atSlot: slotIndex)
        }
    }

    /// Removes files whose bookmark no longer resolves to an existing file. Stacks
    /// lose only their missing files. Items changed or added while validation is in
    /// flight are preserved.
    func cleanupInvalidItems() {
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = Dictionary(uniqueKeysWithValues: self.items.map { ($0.id, $0) })
            let refs = snapshot.values.flatMap { item in
                item.allBookmarkData.map { BookmarkRef(itemID: item.id, data: $0) }
            }
            let validRefs = await Self.validateInParallel(refs)
            guard !Task.isCancelled else { return }
            self.slots = self.reslot(self.slots.map { slot in
                guard let item = slot.item, snapshot[item.id] == item else { return slot }
                let valid = item.allBookmarkData.filter {
                    validRefs.contains(BookmarkRef(itemID: item.id, data: $0))
                }
                switch valid.count {
                case item.allBookmarkData.count:
                    return slot
                case 0:
                    return ShelfSlot(id: slot.id)
                case 1:
                    var pruned = slot
                    pruned.item = ShelfItem(id: item.id, bookmarkData: valid[0])
                    return pruned
                default:
                    var pruned = slot
                    pruned.item = ShelfItem(id: item.id, stackBookmarkData: valid)
                    return pruned
                }
            })
            self.cleanupTask = nil
        }
    }

    private struct BookmarkRef: Hashable, Sendable {
        let itemID: ShelfItem.ID
        let data: Data
    }

    private static func validateInParallel(_ refs: [BookmarkRef]) async -> Set<BookmarkRef> {
        let maxConcurrency = 8
        return await withTaskGroup(of: (BookmarkRef, Bool).self) { group in
            var iterator = refs.makeIterator()
            var inFlight = 0

            while inFlight < maxConcurrency, let ref = iterator.next() {
                group.addTask { (ref, await Bookmark(data: ref.data).validate()) }
                inFlight += 1
            }

            var valid: Set<BookmarkRef> = []
            while let (ref, isValid) = await group.next() {
                if isValid { valid.insert(ref) }
                if let next = iterator.next() {
                    group.addTask { (next, await Bookmark(data: next.data).validate()) }
                }
            }
            return valid
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
        scheduledSaveCount += 1
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
        // Move whole overflow slots (not fresh wrappers) so IDs and copy-mode flags
        // stay stable across repeated `visibleSlots` reads.
        for overflowSlot in slots.dropFirst(target) where overflowSlot.item != nil {
            if let index = visible.firstIndex(where: { $0.item == nil }) {
                visible[index] = overflowSlot
            } else {
                visible.append(overflowSlot)
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

import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("ShelfStore.clearAll")
struct ShelfStoreClearAllTests {
    @Test
    func clearAllEmptiesAllSlotsAndReturnsToMinimumSlotCount() throws {
        let tempDir = try TempDir.make()
        defer { try? FileManager.default.removeItem(at: tempDir.url) }

        let persistence = ShelfPersistenceService(directory: tempDir.url)
        let store = ShelfStore(persistence: persistence, defaults: makeTestUserDefaults())
        let baselineSlotCount = store.slots.count
        let itemsToTriggerGrowth = baselineSlotCount + 1
        let items = try (0..<itemsToTriggerGrowth).map { index in
            let url = try tempDir.url.appendingPathComponent("clear-target-\(index).txt").touch()
            return ShelfItem(bookmarkData: try Bookmark(url: url).data)
        }

        store.add(items)

        #expect(store.items.count == itemsToTriggerGrowth)
        #expect(store.slots.count > baselineSlotCount)

        store.clearAll()

        #expect(store.items.isEmpty)
        #expect(store.slots.count == baselineSlotCount)
        #expect(store.slots.allSatisfy { $0.item == nil })
    }
}

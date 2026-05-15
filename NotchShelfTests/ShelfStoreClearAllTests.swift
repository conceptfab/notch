import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("ShelfStore.clearAll")
struct ShelfStoreClearAllTests {
    @Test
    func clearAllEmptiesAllSlotsAndPreservesBaselineSlotCount() throws {
        let tempDir = try TempDir.make()
        defer { try? FileManager.default.removeItem(at: tempDir.url) }
        let url = try tempDir.url.appendingPathComponent("clear-target.txt").touch()
        let bookmark = try Bookmark(url: url).data

        let persistence = ShelfPersistenceService(directory: tempDir.url)
        let store = ShelfStore(persistence: persistence)
        store.add([ShelfItem(bookmarkData: bookmark)])

        #expect(store.items.count == 1)
        let originalSlotCount = store.slots.count

        store.clearAll()

        #expect(store.items.isEmpty)
        #expect(store.slots.count == originalSlotCount)
        #expect(store.slots.allSatisfy { $0.item == nil })
    }
}

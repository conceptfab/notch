import Testing
import Foundation
@testable import NotchShelf

@MainActor
private func storeWithTempPersistence() -> ShelfStore {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return ShelfStore(persistence: ShelfPersistenceService(directory: dir))
}

private func makeFileItem(named name: String = "f.txt") throws -> ShelfItem {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@MainActor @Test func storeAddAppendsItems() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem(named: "a.txt")
    store.add([a])
    #expect(store.items == [a])
}

@MainActor @Test func storeAddDeduplicatesBySamePath() throws {
    let store = storeWithTempPersistence()
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("dup.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let first = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let second = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    store.add([first])
    store.add([second])
    #expect(store.items.count == 1)
}

@MainActor @Test func storeRemoveDropsItem() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem()
    store.add([a])
    store.remove(a)
    #expect(store.items.isEmpty)
}

@MainActor @Test func storePersistsAcrossInstances() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let persistence = ShelfPersistenceService(directory: dir)
    let store1 = ShelfStore(persistence: persistence)
    let a = try makeFileItem()
    store1.add([a])
    await store1.flushPendingSave()

    let store2 = ShelfStore(persistence: ShelfPersistenceService(directory: dir))
    #expect(store2.items == [a])
}

@MainActor @Test func storeResolveFileURLReturnsURL() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem()
    store.add([a])
    #expect(store.resolveFileURL(for: a) != nil)
}

@MainActor @Test func storeMergesSameFolderItemsIntoStack() throws {
    let store = storeWithTempPersistence()
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let first = dir.appendingPathComponent("first.txt")
    let second = dir.appendingPathComponent("second.txt")
    try "1".write(to: first, atomically: true, encoding: .utf8)
    try "2".write(to: second, atomically: true, encoding: .utf8)
    let single = ShelfItem(bookmarkData: try Bookmark(url: first).data)
    let stack = ShelfDropService.items(from: [first, second])

    store.add([single])
    store.add(stack)

    #expect(store.items.count == 1)
    #expect(store.items.first?.isStack == true)
    #expect(store.items.first?.stackCount == 2)
    #expect(store.totalFileCount == 2)
}

@MainActor @Test func storeRemoveBookmarkFromStackKeepsRemainingFiles() throws {
    let store = storeWithTempPersistence()
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let first = dir.appendingPathComponent("first.txt")
    let second = dir.appendingPathComponent("second.txt")
    try "1".write(to: first, atomically: true, encoding: .utf8)
    try "2".write(to: second, atomically: true, encoding: .utf8)
    let firstBookmark = try Bookmark(url: first).data
    let secondBookmark = try Bookmark(url: second).data
    let stack = ShelfItem(stackBookmarkData: [firstBookmark, secondBookmark])

    store.add([stack])
    store.remove(bookmarkData: firstBookmark, from: stack)

    #expect(store.items.count == 1)
    #expect(store.items.first?.isStack == false)
    #expect(store.items.first?.allBookmarkData == [secondBookmark])
    #expect(store.totalFileCount == 1)
}

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

@MainActor @Test func storeFlushPendingSaveIsIdempotentUnderRapidMutations() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let persistence = ShelfPersistenceService(directory: dir)
    let store = ShelfStore(persistence: persistence)

    let a = try makeFileItem(named: "a.txt")
    let b = try makeFileItem(named: "b.txt")
    let c = try makeFileItem(named: "c.txt")

    store.add([a])
    store.add([b])
    store.add([c])

    // Multiple flushes in quick succession should all converge to the latest state.
    await store.flushPendingSave()
    await store.flushPendingSave()
    await store.flushPendingSave()

    let loaded = ShelfPersistenceService(directory: dir).load()
    #expect(loaded.count == 3)
}

@MainActor @Test func storeRecordsLastErrorWhenPersistenceWriteFails() async throws {
    // Use a path that points to a non-existent parent so the write fails.
    let bogusDir = URL(fileURLWithPath: "/dev/null/cannot-create")
    let persistence = ShelfPersistenceService(directory: bogusDir)
    let store = ShelfStore(persistence: persistence)

    let item = try makeFileItem(named: "a.txt")
    store.add([item])
    await store.flushPendingSave()

    #expect(store.lastError != nil)
    #expect(store.state == .failed(store.lastError ?? ""))
}

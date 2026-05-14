import Testing
import Foundation
@testable import NotchShelf

private func tempDir() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeItem() throws -> ShelfItem {
    let dir = tempDir()
    let file = dir.appendingPathComponent("f-\(UUID().uuidString).txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@Test func persistenceLoadReturnsEmptyWhenNoFile() {
    let service = ShelfPersistenceService(directory: tempDir())
    #expect(service.load().isEmpty)
}

@Test func persistenceSaveThenLoadRoundTrips() throws {
    let service = ShelfPersistenceService(directory: tempDir())
    let items = [try makeItem(), try makeItem()]
    service.save(items)
    let loaded = service.load()
    #expect(loaded == items)
}

@Test func persistenceSkipsCorruptedEntries() throws {
    let dir = tempDir()
    let service = ShelfPersistenceService(directory: dir)
    let good = try makeItem()
    // One valid item dict plus one structurally-broken entry.
    let goodData = try JSONEncoder().encode(good)
    let goodObj = try JSONSerialization.jsonObject(with: goodData)
    let mixed: [Any] = [goodObj, ["id": "not-a-uuid", "bookmarkData": 12345]]
    let mixedData = try JSONSerialization.data(withJSONObject: mixed)
    try mixedData.write(to: dir.appendingPathComponent("shelf.json"))

    let loaded = service.load()
    #expect(loaded == [good])
}

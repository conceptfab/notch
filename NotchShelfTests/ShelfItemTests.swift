import Testing
import Foundation
@testable import NotchShelf

private func makeTempFile(named name: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let file = url.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return file
}

@Test func shelfItemFileURLResolvesToOriginal() throws {
    let file = try makeTempFile(named: "Photo.png")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    #expect(item.fileURL?.standardizedFileURL.path == file.standardizedFileURL.path)
}

@Test func shelfItemIdentityKeyIsStablePerPath() throws {
    let file = try makeTempFile(named: "Doc.txt")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let a = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let b = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    #expect(a.identityKey == b.identityKey)
    #expect(a.id != b.id)
}

@Test func shelfItemRoundTripsThroughCodable() throws {
    let file = try makeTempFile(named: "Codable.txt")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let encoded = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(ShelfItem.self, from: encoded)
    #expect(decoded == item)
}

@Test func shelfItemStackExposesAllFiles() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let first = dir.appendingPathComponent("a.txt")
    let second = dir.appendingPathComponent("b.txt")
    try "a".write(to: first, atomically: true, encoding: .utf8)
    try "b".write(to: second, atomically: true, encoding: .utf8)

    let item = ShelfItem(stackBookmarkData: [
        try Bookmark(url: first).data,
        try Bookmark(url: second).data
    ])

    #expect(item.isStack)
    #expect(item.stackCount == 2)
    #expect(item.fileURLs.map(\.lastPathComponent).sorted() == ["a.txt", "b.txt"])
}

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

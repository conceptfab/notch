import Testing
import Foundation
@testable import NotchShelf

@Test func viewDataFallsBackToLastPathComponent() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("hello.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)

    let viewData = ShelfItemViewData.build(from: item)

    #expect(viewData.displayName == "hello.txt" || viewData.displayName.hasPrefix("hello"))
    #expect(viewData.isStack == false)
}

@Test func viewDataStackFormatsAsFolderWithCount() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString + "_folder", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let first = dir.appendingPathComponent("a.txt")
    let second = dir.appendingPathComponent("b.txt")
    try "x".write(to: first, atomically: true, encoding: .utf8)
    try "y".write(to: second, atomically: true, encoding: .utf8)
    let bookmarks = [
        try Bookmark(url: first).data,
        try Bookmark(url: second).data
    ]
    let stack = ShelfItem(stackBookmarkData: bookmarks)

    let viewData = ShelfItemViewData.build(from: stack)

    #expect(viewData.isStack == true)
    #expect(viewData.stackCount == 2)
    #expect(viewData.displayName.contains("(2)"))
}

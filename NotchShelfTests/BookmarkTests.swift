import Testing
import Foundation
@testable import NotchShelf

@Test func bookmarkCreatesAndResolvesToSameFile() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "data".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let bookmark = try Bookmark(url: tmp)
    let resolved = bookmark.resolveURL()
    #expect(resolved?.standardizedFileURL.path == tmp.standardizedFileURL.path)
}

@Test func bookmarkInitThrowsForMissingFile() {
    let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
    #expect(throws: (any Error).self) { _ = try Bookmark(url: missing) }
}

@Test func bookmarkResolveReturnsNilForEmptyData() {
    let bookmark = Bookmark(data: Data())
    #expect(bookmark.resolveURL() == nil)
}

@Test func bookmarkValidateIsTrueForExistingFileFalseAfterDeletion() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "data".write(to: tmp, atomically: true, encoding: .utf8)
    let bookmark = try Bookmark(url: tmp)
    let validBefore = await bookmark.validate()
    #expect(validBefore == true)

    try FileManager.default.removeItem(at: tmp)
    let validAfter = await bookmark.validate()
    #expect(validAfter == false)
}

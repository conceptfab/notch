import AppKit
import Foundation
import Testing
@testable import NotchShelf

@Test func thumbnailServiceReturnsImageForRealFile() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let file = dir.appendingPathComponent("note.txt")
    try "hello thumbnail".write(to: file, atomically: true, encoding: .utf8)

    let image = await ThumbnailService.shared.thumbnail(
        for: file, size: CGSize(width: 56, height: 56)
    )
    #expect(image != nil)
}

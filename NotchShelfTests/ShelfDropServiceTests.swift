import Testing
import Foundation
@testable import NotchShelf

@Test func dropServiceCreatesItemFromFileProvider() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("dropped.txt")
    try "content".write(to: file, atomically: true, encoding: .utf8)

    let provider = NSItemProvider()
    provider.registerObject(file as NSURL, visibility: .all)

    let items = await ShelfDropService.items(from: [provider])
    #expect(items.count == 1)
    #expect(items.first?.fileURL?.standardizedFileURL.path == file.standardizedFileURL.path)
}

@Test func dropServiceIgnoresNonFileProviders() async {
    let provider = NSItemProvider(object: "just text" as NSString)
    let items = await ShelfDropService.items(from: [provider])
    #expect(items.isEmpty)
}

@Test func dropServiceGroupsFilesFromSameFolderIntoStack() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let first = dir.appendingPathComponent("first.txt")
    let second = dir.appendingPathComponent("second.txt")
    try "1".write(to: first, atomically: true, encoding: .utf8)
    try "2".write(to: second, atomically: true, encoding: .utf8)

    let items = ShelfDropService.items(from: [first, second])

    #expect(items.count == 1)
    #expect(items.first?.isStack == true)
    #expect(items.first?.stackCount == 2)
}

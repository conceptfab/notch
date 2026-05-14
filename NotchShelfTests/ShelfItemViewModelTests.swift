import AppKit
import Foundation
import Testing
@testable import NotchShelf

@MainActor
private func fileItem(named name: String = "vm.txt") throws -> ShelfItem {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@MainActor @Test func itemViewModelExposesIconWithNonZeroSize() throws {
    let viewModel = ShelfItemViewModel(item: try fileItem())
    #expect(viewModel.icon.size.width > 0)
}

@MainActor @Test func itemViewModelStartsNotSelected() throws {
    let viewModel = ShelfItemViewModel(item: try fileItem())
    #expect(viewModel.isSelected == false)
}

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

@MainActor @Test func iconMatchesNSWorkspaceForResolvedURL() throws {
    let tempDir = try TempDir.make()
    defer { try? FileManager.default.removeItem(at: tempDir.url) }
    let url = try tempDir.url.appendingPathComponent("doc.txt").touch()
    let item = ShelfItem(bookmarkData: try Bookmark(url: url).data)

    let viewModel = ShelfItemViewModel(item: item)
    let expected = NSWorkspace.shared.icon(forFile: url.path)
    #expect(viewModel.icon.size == expected.size)
}

@MainActor @Test func itemViewModelStartsNotSelected() throws {
    let viewModel = ShelfItemViewModel(item: try fileItem())
    #expect(viewModel.isSelected == false)
}

@MainActor
private final class FakeShelfStore: ShelfStoring {
    var items: [ShelfItem] = []

    func add(_ items: [ShelfItem]) {
        self.items.append(contentsOf: items)
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func remove(bookmarkData: Data, from item: ShelfItem) {}

    func resolveFileURLs(for item: ShelfItem) -> [URL] { [] }
}

@MainActor
private final class FakeSelection: SelectionStoring {
    var selectedIDs: Set<UUID> = []
    var isDragging = false
    var lastShiftSelectAnchor: UUID?

    func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    func selectSingle(_ item: ShelfItem) {
        selectedIDs = [item.id]
    }

    func toggle(_ item: ShelfItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem]) {
        lastShiftSelectAnchor = item.id
    }

    func clear() {
        selectedIDs.removeAll()
    }

    func beginDrag() {
        isDragging = true
    }

    func endDrag() {
        isDragging = false
    }
}

@MainActor @Test func viewModelUsesInjectedDependencies() throws {
    let item = try fileItem(named: "a.txt")
    let store = FakeShelfStore()
    store.items = [item]
    let selection = FakeSelection()

    let viewModel = ShelfItemViewModel(item: item, store: store, selection: selection)

    #expect(viewModel.isSelected == false)
    selection.selectSingle(item)
    #expect(viewModel.isSelected == true)
}

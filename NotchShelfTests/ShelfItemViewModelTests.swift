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
    var keepAfterExternalDropIDs: Set<UUID> = []
    var resolvedURLsByItemID: [UUID: [URL]] = [:]
    var removedItemIDs: [UUID] = []
    var removedBookmarkData: [(Data, UUID)] = []

    func add(_ items: [ShelfItem]) {
        self.items.append(contentsOf: items)
    }

    func remove(_ item: ShelfItem) {
        removedItemIDs.append(item.id)
        items.removeAll { $0.id == item.id }
    }

    func remove(bookmarkData: Data, from item: ShelfItem) {
        removedBookmarkData.append((bookmarkData, item.id))
    }

    func keepsItemAfterExternalDrop(_ item: ShelfItem) -> Bool {
        keepAfterExternalDropIDs.contains(item.id)
    }

    func resolveFileURLs(for item: ShelfItem) -> [URL] {
        resolvedURLsByItemID[item.id] ?? []
    }
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

@MainActor @Test func dragItemsUsesSelectedGroupWhenDraggedItemIsSelected() throws {
    let itemA = try fileItem(named: "a.txt")
    let itemB = try fileItem(named: "b.txt")
    let store = FakeShelfStore()
    store.items = [itemA, itemB]
    let selection = FakeSelection()
    selection.selectedIDs = [itemA.id, itemB.id]

    let viewModel = ShelfItemViewModel(item: itemA, store: store, selection: selection)

    #expect(viewModel.dragItems(containing: itemA).map(\.id) == [itemA.id, itemB.id])
}

@MainActor @Test func dragItemsFallsBackToSingleItemWhenDraggedItemIsNotInSelection() throws {
    let itemA = try fileItem(named: "a.txt")
    let itemB = try fileItem(named: "b.txt")
    let store = FakeShelfStore()
    store.items = [itemA, itemB]
    let selection = FakeSelection()
    selection.selectedIDs = [itemB.id]

    let viewModel = ShelfItemViewModel(item: itemA, store: store, selection: selection)

    #expect(viewModel.dragItems(containing: itemA).map(\.id) == [itemA.id])
}

@MainActor @Test func dragHelpersDelegateToInjectedDependencies() throws {
    let item = try fileItem(named: "delegate.txt")
    let tempDir = try TempDir.make()
    defer { try? FileManager.default.removeItem(at: tempDir.url) }
    let url = try tempDir.url.appendingPathComponent("resolved.txt").touch()
    let store = FakeShelfStore()
    store.items = [item]
    store.keepAfterExternalDropIDs = [item.id]
    store.resolvedURLsByItemID[item.id] = [url]
    let selection = FakeSelection()
    let suiteName = "ShelfItemViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(true, forKey: UserDefaultsKey.copyOnDrag)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let viewModel = ShelfItemViewModel(
        item: item,
        store: store,
        selection: selection,
        defaults: defaults
    )

    #expect(viewModel.keepsItemAfterExternalDrop(item) == true)
    #expect(viewModel.resolveFileURLs(for: item) == [url])
    #expect(viewModel.copyOnDragPreferenceEnabled == true)

    viewModel.beginExternalDrag()
    #expect(selection.isDragging == true)
    viewModel.endExternalDrag()
    #expect(selection.isDragging == false)

    viewModel.removeFromShelf(item)
    #expect(store.removedItemIDs == [item.id])

    let data = Data([1, 2, 3])
    viewModel.removeFromStack(bookmarkData: data, from: item)
    #expect(store.removedBookmarkData.count == 1)
    #expect(store.removedBookmarkData.first?.0 == data)
    #expect(store.removedBookmarkData.first?.1 == item.id)

    selection.selectedIDs = [item.id]
    viewModel.clearSelection()
    #expect(selection.selectedIDs.isEmpty)
}

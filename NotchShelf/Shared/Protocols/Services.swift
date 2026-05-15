import Foundation

/// Read-only view of the shelf's items, plus mutation helpers used by drag handlers
/// and the action service.
@MainActor
protocol ShelfStoring: AnyObject {
    var items: [ShelfItem] { get }
    func add(_ items: [ShelfItem])
    func remove(_ item: ShelfItem)
    func remove(bookmarkData: Data, from item: ShelfItem)
    func resolveFileURLs(for item: ShelfItem) -> [URL]
}

/// Multi-selection state.
@MainActor
protocol SelectionStoring: AnyObject {
    var selectedIDs: Set<UUID> { get }
    var isDragging: Bool { get }
    func isSelected(_ id: UUID) -> Bool
    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem]
    func selectSingle(_ item: ShelfItem)
    func toggle(_ item: ShelfItem)
    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem])
    func clear()
    func beginDrag()
    func endDrag()
}

import Foundation
import Combine

/// Multi-selection state for the shelf, with shift-range support and a drag flag.
@MainActor
final class ShelfSelection: ObservableObject {
    static let shared = ShelfSelection()

    @Published private(set) var selectedIDs: Set<UUID> = []
    @Published private(set) var isDragging: Bool = false

    /// Anchor for shift-range selection.
    private var lastAnchorID: UUID?

    init() {}

    func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    var hasSelection: Bool { !selectedIDs.isEmpty }

    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    func selectSingle(_ item: ShelfItem) {
        selectedIDs = [item.id]
        lastAnchorID = item.id
    }

    func toggle(_ item: ShelfItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        lastAnchorID = item.id
    }

    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem]) {
        let anchorID = lastAnchorID ?? selectedIDs.first ?? item.id
        guard let start = allItems.firstIndex(where: { $0.id == anchorID }),
              let end = allItems.firstIndex(where: { $0.id == item.id }) else {
            return selectSingle(item)
        }
        let range = min(start, end)...max(start, end)
        selectedIDs = Set(allItems[range].map(\.id))
    }

    func clear() {
        selectedIDs.removeAll()
        lastAnchorID = nil
    }

    func beginDrag() { isDragging = true }
    func endDrag() { isDragging = false }
}

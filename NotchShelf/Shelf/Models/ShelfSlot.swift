import Foundation

struct ShelfSlot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var item: ShelfItem?

    init(id: UUID = UUID(), item: ShelfItem? = nil) {
        self.id = id
        self.item = item
    }
}

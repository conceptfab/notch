import Foundation

struct ShelfSlot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var item: ShelfItem?
    var keepsItemAfterExternalDrop: Bool

    init(id: UUID = UUID(), item: ShelfItem? = nil, keepsItemAfterExternalDrop: Bool = false) {
        self.id = id
        self.item = item
        self.keepsItemAfterExternalDrop = keepsItemAfterExternalDrop
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case item
        case keepsItemAfterExternalDrop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        item = try container.decodeIfPresent(ShelfItem.self, forKey: .item)
        keepsItemAfterExternalDrop = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepsItemAfterExternalDrop
        ) ?? false
    }
}

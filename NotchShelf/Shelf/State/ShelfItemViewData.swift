import Foundation

/// Presentation-layer view of a `ShelfItem`. Built by `ShelfItemViewModel`, consumed
/// by views. Keeps formatting concerns out of the domain `ShelfItem`.
struct ShelfItemViewData: Equatable, Hashable {
    let id: UUID
    let displayName: String
    let isStack: Bool
    let stackCount: Int

    static func build(from item: ShelfItem) -> ShelfItemViewData {
        ShelfItemViewData(
            id: item.id,
            displayName: makeDisplayName(item),
            isStack: item.isStack,
            stackCount: item.stackCount
        )
    }

    private static func makeDisplayName(_ item: ShelfItem) -> String {
        guard let url = item.fileURL else { return "Unknown file" }
        if item.isStack {
            let folder = url.deletingLastPathComponent().lastPathComponent
            return "\(folder) (\(item.stackCount))"
        }
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
            ?? url.lastPathComponent
    }
}

import Foundation

/// JSON persistence for the shelf. Stores items at
/// `~/Library/Application Support/NotchShelf/shelf.json`.
final class ShelfPersistenceService: @unchecked Sendable {
    static let shared = ShelfPersistenceService()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// - Parameter directory: storage directory. Defaults to the app support folder;
    ///   tests pass a temporary directory.
    init(directory: URL? = nil) {
        let fm = FileManager.default
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let support = try? fm.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask, appropriateFor: nil, create: true)
            dir = (support ?? fm.temporaryDirectory)
                .appendingPathComponent("NotchShelf", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("shelf.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    /// Loads the shelf. Corrupted individual entries are skipped rather than failing the whole load.
    func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let items = try? decoder.decode([ShelfItem].self, from: data) {
            return items
        }
        if let slots = try? decoder.decode([ShelfSlot].self, from: data) {
            return slots.compactMap(\.item)
        }

        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            NSLog("Shelf persistence file is not a valid JSON array")
            return []
        }

        var valid: [ShelfItem] = []
        var failed = 0
        for entry in jsonArray {
            if let entryData = try? JSONSerialization.data(withJSONObject: entry),
               let item = try? decoder.decode(ShelfItem.self, from: entryData) {
                valid.append(item)
            } else {
                failed += 1
            }
        }
        if failed > 0 {
            NSLog("Loaded \(valid.count) shelf items, discarded \(failed) corrupted")
        }
        return valid
    }

    func loadSlots() -> [ShelfSlot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let slots = try? decoder.decode([ShelfSlot].self, from: data) {
            return slots
        }
        return load().map { ShelfSlot(item: $0) }
    }

    @discardableResult
    func save(_ items: [ShelfItem]) -> Result<Void, Error> {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            NSLog("Failed to save shelf items: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    @discardableResult
    func save(_ slots: [ShelfSlot]) -> Result<Void, Error> {
        do {
            let data = try encoder.encode(slots)
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            NSLog("Failed to save shelf slots: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

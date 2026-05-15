import Foundation

/// One file or same-folder stack parked on the shelf. Holds only security-scoped
/// bookmarks — the original files are never copied or moved.
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var bookmarkData: Data
    var stackBookmarkData: [Data]?

    init(id: UUID = UUID(), bookmarkData: Data, stackBookmarkData: [Data]? = nil) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.stackBookmarkData = stackBookmarkData
    }

    init(id: UUID = UUID(), stackBookmarkData: [Data]) {
        self.id = id
        self.bookmarkData = stackBookmarkData.first ?? Data()
        self.stackBookmarkData = stackBookmarkData
    }

    var allBookmarkData: [Data] {
        guard let stackBookmarkData, !stackBookmarkData.isEmpty else {
            return [bookmarkData]
        }
        return stackBookmarkData
    }

    var isStack: Bool { allBookmarkData.count > 1 }

    var stackCount: Int { allBookmarkData.count }

    /// Current location of the file, or nil if the bookmark can no longer be resolved.
    var fileURL: URL? {
        Bookmark(data: bookmarkData).resolveURL()
    }

    var sourceFolderKey: String? {
        guard let url = fileURL else { return nil }
        return url.deletingLastPathComponent().standardizedFileURL.path
    }

    /// Stable key for deduplication: the standardized file path, or the bookmark bytes
    /// when the file cannot currently be resolved.
    var identityKey: String {
        if isStack {
            let keys = allBookmarkData.map { data in
                if let url = Bookmark(data: data).resolveURL() {
                    return "file://" + url.standardizedFileURL.path
                }
                return "file://missing/" + data.base64EncodedString()
            }
            return "stack://" + keys.sorted().joined(separator: "|")
        }
        if let url = fileURL {
            return "file://" + url.standardizedFileURL.path
        }
        return "file://missing/" + bookmarkData.base64EncodedString()
    }

    func merging(with other: ShelfItem) -> ShelfItem {
        var mergedData: [Data] = []
        var seen: Set<String> = []
        for data in allBookmarkData + other.allBookmarkData {
            let key = Bookmark(data: data).resolveURL()?.standardizedFileURL.path
                ?? data.base64EncodedString()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            mergedData.append(data)
        }
        return ShelfItem(id: id, stackBookmarkData: mergedData)
    }
}

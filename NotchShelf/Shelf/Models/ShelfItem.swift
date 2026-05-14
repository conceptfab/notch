import Foundation

/// One file (or folder) parked on the shelf. Holds only a security-scoped bookmark —
/// the original file is never copied or moved.
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var bookmarkData: Data

    init(id: UUID = UUID(), bookmarkData: Data) {
        self.id = id
        self.bookmarkData = bookmarkData
    }

    /// Current location of the file, or nil if the bookmark can no longer be resolved.
    var fileURL: URL? {
        Bookmark(data: bookmarkData).resolveURL()
    }

    /// Finder-style display name, falling back to the last path component.
    var displayName: String {
        guard let url = fileURL else { return "Unknown file" }
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
            ?? url.lastPathComponent
    }

    /// Stable key for deduplication: the standardized file path, or the bookmark bytes
    /// when the file cannot currently be resolved.
    var identityKey: String {
        if let url = fileURL {
            return "file://" + url.standardizedFileURL.path
        }
        return "file://missing/" + bookmarkData.base64EncodedString()
    }
}

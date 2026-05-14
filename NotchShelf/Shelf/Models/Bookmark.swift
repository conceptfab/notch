import Foundation

/// A security-scoped bookmark to a user-selected file. Survives app restarts and
/// transparently refreshes itself when macOS marks the bookmark stale.
struct Bookmark: Sendable, Equatable, Codable {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(url: URL) throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "Bookmark", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Not a valid file URL or file missing at \(url.path)"]
            )
        }
        self.data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves the bookmark. Returns the URL and, if the bookmark was stale,
    /// freshly regenerated bookmark data the caller should persist.
    func resolve() -> (url: URL?, refreshedData: Data?) {
        guard !data.isEmpty else { return (nil, nil) }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale, let newData = try? url.bookmarkData(options: [.withSecurityScope]) {
                return (url, newData)
            }
            return (url, nil)
        } catch {
            NSLog("Bookmark resolve failed: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    func resolveURL() -> URL? { resolve().url }

    var refreshedData: Data? { resolve().refreshedData }

    /// True if the bookmark still points at an existing file.
    func validate() async -> Bool {
        guard let url = resolve().url else { return false }
        return url.accessSecurityScopedResource { FileManager.default.fileExists(atPath: $0.path) }
    }
}

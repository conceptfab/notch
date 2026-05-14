import Foundation

/// Converts dropped `NSItemProvider`s into `ShelfItem`s. Files only — anything that
/// is not a file-system URL is ignored.
enum ShelfDropService {
    static func items(from providers: [NSItemProvider]) async -> [ShelfItem] {
        var urls: [URL] = []
        for provider in providers {
            guard let url = await provider.extractFileURL() else { continue }
            urls.append(url)
        }
        return items(from: urls)
    }

    static func items(from urls: [URL]) -> [ShelfItem] {
        let grouped = Dictionary(grouping: urls) {
            $0.deletingLastPathComponent().standardizedFileURL.path
        }
        return grouped.keys.sorted().flatMap { key -> [ShelfItem] in
            guard let group = grouped[key] else { return [] }
            let bookmarks = group.compactMap { try? Bookmark(url: $0).data }
            guard !bookmarks.isEmpty else { return [] }
            if bookmarks.count > 1 {
                return [ShelfItem(stackBookmarkData: bookmarks)]
            }
            return [ShelfItem(bookmarkData: bookmarks[0])]
        }
    }
}

import Foundation

/// Converts dropped `NSItemProvider`s into `ShelfItem`s. Files only — anything that
/// is not a file-system URL is ignored.
enum ShelfDropService {
    static func items(from providers: [NSItemProvider]) async -> [ShelfItem] {
        var results: [ShelfItem] = []
        for provider in providers {
            guard let url = await provider.extractFileURL() else { continue }
            guard let bookmark = try? Bookmark(url: url) else { continue }
            results.append(ShelfItem(bookmarkData: bookmark.data))
        }
        return results
    }
}

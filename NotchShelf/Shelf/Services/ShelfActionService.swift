import AppKit
import Foundation

/// Common actions for shelf items: open, reveal in Finder, copy path, remove.
@MainActor
enum ShelfActionService {
    static func open(_ item: ShelfItem) {
        for bookmarkData in item.allBookmarkData {
            handleBookmarkedFile(bookmarkData) { NSWorkspace.shared.open($0) }
        }
    }

    static func open(bookmarkData: Data) {
        handleBookmarkedFile(bookmarkData) { NSWorkspace.shared.open($0) }
    }

    static func reveal(_ item: ShelfItem) {
        handleBookmarkedFiles(item.allBookmarkData) {
            NSWorkspace.shared.activateFileViewerSelecting($0)
        }
    }

    static func copyPath(_ item: ShelfItem) {
        handleBookmarkedFiles(item.allBookmarkData) { urls in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        }
    }

    static func remove(_ item: ShelfItem) {
        ShelfStore.shared.remove(item)
    }

    private static func handleBookmarkedFile(
        _ bookmarkData: Data,
        action: @escaping @Sendable (URL) -> Void
    ) {
        Task {
            guard let url = Bookmark(data: bookmarkData).resolveURL() else { return }
            url.accessSecurityScopedResource { action($0) }
        }
    }

    private static func handleBookmarkedFiles(
        _ bookmarkData: [Data],
        action: @escaping @Sendable ([URL]) -> Void
    ) {
        Task {
            let urls = bookmarkData.compactMap { Bookmark(data: $0).resolveURL() }
            guard !urls.isEmpty else { return }
            let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
            defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
            action(urls)
        }
    }
}

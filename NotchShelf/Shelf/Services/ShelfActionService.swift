import AppKit
import Foundation

/// Common actions for shelf items: open, reveal in Finder, copy path, remove.
@MainActor
enum ShelfActionService {
    static func open(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) { NSWorkspace.shared.open($0) }
    }

    static func reveal(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        }
    }

    static func copyPath(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) { url in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
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
}

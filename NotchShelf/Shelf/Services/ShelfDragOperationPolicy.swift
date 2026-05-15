import AppKit

enum ShelfDragOperationPolicy {
    /// Outside the app we only ever offer `.copy`. NotchShelf holds bookmarks,
    /// not files, so Finder must never be invited to relocate the source file.
    static func sourceOperationMask(copyOnDrag: Bool, context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy]
        case .withinApplication:
            return copyOnDrag ? [.copy] : [.copy, .move, .generic]
        @unknown default:
            return [.copy]
        }
    }

    static func shouldRemoveFromShelf(
        after operation: NSDragOperation,
        context: NSDraggingContext
    ) -> Bool {
        if operation.contains(.move) { return true }

        switch context {
        case .outsideApplication:
            return operation.contains(.copy)
        case .withinApplication:
            return false
        @unknown default:
            return false
        }
    }

    static func shouldRemoveFromShelf(after operation: NSDragOperation) -> Bool {
        shouldRemoveFromShelf(after: operation, context: .withinApplication)
    }
}

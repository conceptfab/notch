import AppKit

enum ShelfDragOperationPolicy {
    /// Finder should be allowed to perform a real file move unless this drag is
    /// explicitly in copy mode. NotchShelf stores bookmarks, but it vends the
    /// original file URL back to AppKit for drag-out.
    static func sourceOperationMask(
        copyOnDrag: Bool,
        context: NSDraggingContext,
        keepAfterExternalDrop: Bool = false
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return keepAfterExternalDrop ? [.copy] : [.copy, .move]
        case .withinApplication:
            return copyOnDrag ? [.copy] : [.copy, .move, .generic]
        @unknown default:
            return [.copy]
        }
    }

    static func shouldRemoveFromShelf(
        after operation: NSDragOperation,
        context: NSDraggingContext,
        keepAfterExternalDrop: Bool = false
    ) -> Bool {
        switch context {
        case .outsideApplication:
            return (operation.contains(.copy) || operation.contains(.move)) && !keepAfterExternalDrop
        case .withinApplication:
            return operation.contains(.move)
        @unknown default:
            return false
        }
    }

    static func shouldRemoveFromShelf(after operation: NSDragOperation) -> Bool {
        shouldRemoveFromShelf(after: operation, context: .withinApplication)
    }
}

import AppKit

enum ShelfDragOperationPolicy {
    static func sourceOperationMask(copyOnDrag: Bool, context: NSDraggingContext) -> NSDragOperation {
        if copyOnDrag { return [.copy] }
        switch context {
        case .outsideApplication:
            return [.copy, .move]
        case .withinApplication:
            return [.copy, .move, .generic]
        @unknown default:
            return [.copy]
        }
    }

    static func shouldRemoveFromShelf(after operation: NSDragOperation) -> Bool {
        operation.contains(.move)
    }
}

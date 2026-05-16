import AppKit
import SwiftUI

struct StackFileDragHandler: NSViewRepresentable {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let previewImage: NSImage

    func makeNSView(context: Context) -> StackFileDragView {
        let view = StackFileDragView()
        view.sourceItem = sourceItem
        view.bookmarkData = entry.bookmarkData
        view.title = entry.title
        view.previewImage = previewImage
        return view
    }

    func updateNSView(_ nsView: StackFileDragView, context: Context) {
        nsView.sourceItem = sourceItem
        nsView.bookmarkData = entry.bookmarkData
        nsView.title = entry.title
        nsView.previewImage = previewImage
    }

    final class StackFileDragView: NSView, NSDraggingSource {
        var sourceItem: ShelfItem?
        var bookmarkData = Data()
        var title = ""
        var previewImage = NSImage()

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURL: URL?
        private var didStartDrag = false
        private var draggedSourceItem: ShelfItem?
        private var draggedBookmarkData = Data()
        private var lastDragContext: NSDraggingContext = .withinApplication

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            didStartDrag = false
        }

        override func mouseUp(with event: NSEvent) {
            guard !didStartDrag else { return }
            ShelfActionService.open(bookmarkData: bookmarkData)
            mouseDownEvent = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }
            let distance = hypot(
                event.locationInWindow.x - down.locationInWindow.x,
                event.locationInWindow.y - down.locationInWindow.y
            )
            if distance > dragThreshold {
                if startDragSession(with: event) {
                    mouseDownEvent = nil
                    didStartDrag = true
                }
            } else {
                super.mouseDragged(with: event)
            }
        }

        @discardableResult
        private func startDragSession(with event: NSEvent) -> Bool {
            guard let url = Bookmark(data: bookmarkData).resolveURL() else { return false }
            if url.startAccessingSecurityScopedResource() {
                draggedURL = url
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: previewImage.size),
                contents: previewImage
            )

            draggedSourceItem = sourceItem
            draggedBookmarkData = bookmarkData
            beginDraggingSession(with: [draggingItem], event: event, source: self)
            return true
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            lastDragContext = context
            let keepAfterExternalDrop = sourceItem.map {
                ShelfStore.shared.keepsItemAfterExternalDrop($0)
            } ?? false
            return ShelfDragOperationPolicy.sourceOperationMask(
                copyOnDrag: UserDefaults.standard.bool(forKey: UserDefaultsKey.copyOnDrag),
                context: context,
                keepAfterExternalDrop: keepAfterExternalDrop
            )
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelection.shared.beginDrag()
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            if let draggedSourceItem,
               ShelfDragOperationPolicy.shouldRemoveFromShelf(
                   after: operation,
                   context: lastDragContext,
                   keepAfterExternalDrop: ShelfStore.shared.keepsItemAfterExternalDrop(draggedSourceItem)
               ) {
                ShelfStore.shared.remove(bookmarkData: draggedBookmarkData, from: draggedSourceItem)
                ShelfSelection.shared.clear()
            }
            ShelfSelection.shared.endDrag()
            draggedURL?.stopAccessingSecurityScopedResource()
            draggedURL = nil
            draggedSourceItem = nil
            draggedBookmarkData = Data()
            didStartDrag = false
            lastDragContext = .withinApplication
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

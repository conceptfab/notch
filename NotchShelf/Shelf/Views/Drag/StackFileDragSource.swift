import AppKit
import SwiftUI

struct StackFileDragHandler: NSViewRepresentable {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let previewImage: NSImage
    var preferences: PreferenceProviding = Preferences.shared

    func makeNSView(context: Context) -> StackFileDragView {
        let view = StackFileDragView()
        view.sourceItem = sourceItem
        view.bookmarkData = entry.bookmarkData
        view.title = entry.title
        view.previewImage = previewImage
        view.preferences = preferences
        return view
    }

    func updateNSView(_ nsView: StackFileDragView, context: Context) {
        nsView.sourceItem = sourceItem
        nsView.bookmarkData = entry.bookmarkData
        nsView.title = entry.title
        nsView.previewImage = previewImage
        nsView.preferences = preferences
    }

    final class StackFileDragView: NSView, NSDraggingSource {
        var sourceItem: ShelfItem?
        var bookmarkData = Data()
        var title = ""
        var previewImage = NSImage()
        var preferences: PreferenceProviding = Preferences.shared

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURL: URL?
        private var didStartDrag = false
        private var removedFromShelf = false

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
                startDragSession(with: event)
                mouseDownEvent = nil
                didStartDrag = true
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            guard let url = Bookmark(data: bookmarkData).resolveURL() else { return }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(url.path, forType: .string)

            if url.startAccessingSecurityScopedResource() {
                draggedURL = url
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: previewImage.size),
                contents: previewImage
            )

            removedFromShelf = false
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if preferences.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.copy, .move, .generic]
            @unknown default:
                return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelection.shared.beginDrag()
            guard !removedFromShelf, let sourceItem else { return }
            ShelfStore.shared.remove(bookmarkData: bookmarkData, from: sourceItem)
            ShelfSelection.shared.clear()
            removedFromShelf = true
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            draggedURL?.stopAccessingSecurityScopedResource()
            draggedURL = nil
            removedFromShelf = false
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

import AppKit
import SwiftUI

struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    let displayName: String
    @Binding var cachedPreviewImage: NSImage?
    let onClick: (NSEvent, NSView) -> Void
    let onRightClick: (NSEvent, NSView) -> Void

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.viewModel = viewModel
        view.dragPreviewImage = cachedPreviewImage ?? viewModel.icon
        view.onClick = onClick
        view.onRightClick = onRightClick
        view.toolTip = displayName
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
        if nsView.toolTip != displayName { nsView.toolTip = displayName }
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem?
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []
        private var draggedItemIDsToKeepAfterExternalDrop: Set<ShelfItem.ID> = []
        private var dragSessionShouldCopyOnlyOutsideApp = false
        private var didStartDrag = false
        private var lastDragContext: NSDraggingContext = .withinApplication

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(event, self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            didStartDrag = false
            onClick?(event, self)
        }

        override func mouseUp(with event: NSEvent) {
            guard !didStartDrag else { return }
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
            guard let item else { return false }
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag
            draggedItemIDsToKeepAfterExternalDrop = Set(
                itemsToDrag
                    .filter { ShelfStore.shared.keepsItemAfterExternalDrop($0) }
                    .map(\.id)
            )
            dragSessionShouldCopyOnlyOutsideApp = !draggedItemIDsToKeepAfterExternalDrop.isEmpty

            var draggingItems: [NSDraggingItem] = []
            for dragItem in itemsToDrag {
                let urls = ShelfStore.shared.resolveFileURLs(for: dragItem)
                if urls.isEmpty {
                    let viewData = ShelfItemViewData.build(from: dragItem)
                    if let pasteboardItem = pasteboardItem(displayName: viewData.displayName) {
                        draggingItems.append(draggingItem(for: pasteboardItem))
                    }
                    continue
                }
                for url in urls {
                    guard let pasteboardWriter = pasteboardWriter(for: url) else { continue }
                    draggingItems.append(draggingItem(for: pasteboardWriter))
                }
            }
            guard !draggingItems.isEmpty else { return false }
            beginDraggingSession(with: draggingItems, event: event, source: self)
            return true
        }

        private func draggingItem(for pasteboardWriter: NSPasteboardWriting) -> NSDraggingItem {
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardWriter)
            let image = dragPreviewImage ?? viewModel?.icon ?? NSImage()
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: image.size),
                contents: image
            )
            return draggingItem
        }

        private func removeDraggedItemsFromShelf(after operation: NSDragOperation) {
            for item in draggedItems {
                let keepAfterExternalDrop = draggedItemIDsToKeepAfterExternalDrop.contains(item.id)
                guard ShelfDragOperationPolicy.shouldRemoveFromShelf(
                    after: operation,
                    context: lastDragContext,
                    keepAfterExternalDrop: keepAfterExternalDrop
                ) else {
                    continue
                }
                ShelfStore.shared.remove(item)
            }
            ShelfSelection.shared.clear()
        }

        private func pasteboardItem(displayName: String) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(displayName, forType: .string)
            return pasteboardItem
        }

        private func pasteboardWriter(for url: URL) -> NSPasteboardWriting? {
            if url.startAccessingSecurityScopedResource() {
                draggedURLs.append(url)
            }
            return url as NSURL
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            lastDragContext = context
            return ShelfDragOperationPolicy.sourceOperationMask(
                copyOnDrag: UserDefaults.standard.bool(forKey: UserDefaultsKey.copyOnDrag),
                context: context,
                keepAfterExternalDrop: dragSessionShouldCopyOnlyOutsideApp
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
            if operation.contains(.move) {
                AppLogger.drag.notice("Drag session ended with .move operation")
            }
            removeDraggedItemsFromShelf(after: operation)
            ShelfSelection.shared.endDrag()
            for url in draggedURLs { url.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()
            draggedItems.removeAll()
            draggedItemIDsToKeepAfterExternalDrop.removeAll()
            dragSessionShouldCopyOnlyOutsideApp = false
            didStartDrag = false
            lastDragContext = .withinApplication
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

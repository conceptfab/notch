import AppKit
import SwiftUI

struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    @Binding var cachedPreviewImage: NSImage?
    let onClick: (NSEvent, NSView) -> Void
    let onRightClick: (NSEvent, NSView) -> Void
    var preferences: PreferenceProviding = Preferences.shared

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.viewModel = viewModel
        view.dragPreviewImage = cachedPreviewImage ?? viewModel.icon
        view.onClick = onClick
        view.onRightClick = onRightClick
        view.preferences = preferences
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
        nsView.preferences = preferences
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem?
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?
        var preferences: PreferenceProviding = Preferences.shared

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(event, self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            onClick?(event, self)
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
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            guard let item else { return }
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag

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
                    guard let pasteboardItem = pasteboardItem(for: url) else { continue }
                    draggingItems.append(draggingItem(for: pasteboardItem))
                }
            }
            guard !draggingItems.isEmpty else { return }
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        private func draggingItem(for pasteboardItem: NSPasteboardItem) -> NSDraggingItem {
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let image = dragPreviewImage ?? viewModel?.icon ?? NSImage()
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: image.size),
                contents: image
            )
            return draggingItem
        }

        private func removeDraggedItemsFromShelf() {
            for item in draggedItems {
                ShelfStore.shared.remove(item)
            }
            ShelfSelection.shared.clear()
        }

        private func pasteboardItem(displayName: String) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(displayName, forType: .string)
            return pasteboardItem
        }

        private func pasteboardItem(for url: URL) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            if url.startAccessingSecurityScopedResource() {
                draggedURLs.append(url)
            }
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(url.path, forType: .string)
            return pasteboardItem
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
            removeDraggedItemsFromShelf()
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            for url in draggedURLs { url.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

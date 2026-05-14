import AppKit
import SwiftUI

/// A single shelf item card: thumbnail, name, selection styling, and an AppKit drag
/// source for dragging the file back out into Finder.
struct ShelfItemView: View {
    let item: ShelfItem
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var selection = ShelfSelection.shared
    @StateObject private var viewModel: ShelfItemViewModel
    @State private var cachedPreviewImage: NSImage?
    @State private var debouncedDropTarget = false

    private var isSelected: Bool { viewModel.isSelected }

    init(item: ShelfItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ShelfItemViewModel(item: item))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 2) {
                iconView
                textView
            }
            .frame(width: 105)
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .background(backgroundView)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.1), value: debouncedDropTarget)
            .animation(.easeInOut(duration: 0.1), value: isSelected)

            DraggableClickHandler(
                item: item,
                viewModel: viewModel,
                cachedPreviewImage: $cachedPreviewImage,
                onClick: { event, nsView in viewModel.handleClick(event: event, view: nsView) },
                onRightClick: { event, nsView in viewModel.handleRightClick(event: event, view: nsView) }
            )
        }
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            windowModel.dragTargeting = targeted
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            Task {
                await viewModel.loadThumbnail()
                if cachedPreviewImage == nil {
                    cachedPreviewImage = await renderDragPreview()
                }
            }
        }
        .onChange(of: viewModel.thumbnail) { _, _ in
            Task { cachedPreviewImage = await renderDragPreview() }
        }
    }

    private var iconView: some View {
        Image(nsImage: viewModel.thumbnail ?? viewModel.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }

    private var textView: some View {
        Text(item.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(height: 30, alignment: .top)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            )
    }

    private var backgroundColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.25) }
        if isSelected { return Color.accentColor.opacity(0.15) }
        return Color.clear
    }

    private var strokeColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.9) }
        if isSelected { return Color.accentColor.opacity(0.8) }
        return Color.clear
    }

    private var strokeWidth: CGFloat {
        if debouncedDropTarget { return 3 }
        if isSelected { return 2 }
        return 1
    }

    @MainActor
    private func renderDragPreview() async -> NSImage {
        let content = DragPreviewView(
            thumbnail: viewModel.thumbnail ?? viewModel.icon,
            displayName: item.displayName
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? (viewModel.thumbnail ?? viewModel.icon)
    }
}

// MARK: - AppKit drag source

/// Hosts an `NSView` that turns a press-and-drag into an `NSDraggingSession`.
private struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
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
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem!
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?

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
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag

            var draggingItems: [NSDraggingItem] = []
            for dragItem in itemsToDrag {
                guard let pasteboardItem = pasteboardItem(for: dragItem) else { continue }
                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
                let image = dragPreviewImage ?? viewModel?.icon ?? NSImage()
                draggingItem.setDraggingFrame(
                    NSRect(origin: .zero, size: image.size),
                    contents: image
                )
                draggingItems.append(draggingItem)
            }
            guard !draggingItems.isEmpty else { return }
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        private func pasteboardItem(for item: ShelfItem) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            guard let url = ShelfStore.shared.resolveAndUpdateBookmark(for: item) else {
                pasteboardItem.setString(item.displayName, forType: .string)
                return pasteboardItem
            }

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
            if Preferences.shared.copyOnDrag { return [.copy] }
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
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            for url in draggedURLs { url.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()

            if !operation.isEmpty {
                for item in draggedItems { ShelfStore.shared.remove(item) }
            }
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

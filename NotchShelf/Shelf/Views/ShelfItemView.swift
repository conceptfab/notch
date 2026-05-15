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
    @State private var dropTargetDebounceTask: Task<Void, Never>?
    @State private var showingStackList = false

    private var isSelected: Bool { viewModel.isSelected }

    init(item: ShelfItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ShelfItemViewModel(item: item))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 2) {
                iconView
                if item.isStack {
                    Color.clear.frame(width: 14, height: 14)
                }
                textView
            }
            .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemHeight)
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

            if item.isStack {
                VStack(spacing: 0) {
                    Spacer().frame(height: 29)
                    stackListButton
                    Spacer(minLength: 0)
                }
            }
        }
        .background {
            if item.isStack {
                StackFileListPanelPresenter(item: item, isPresented: $showingStackList)
            }
        }
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            windowModel.dragTargeting = targeted
            dropTargetDebounceTask?.cancel()
            dropTargetDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            viewModel.loadThumbnail()
            Task { @MainActor in
                if cachedPreviewImage == nil {
                    cachedPreviewImage = await renderDragPreview()
                }
            }
        }
        .onChange(of: viewModel.thumbnail) { _, _ in
            Task { cachedPreviewImage = await renderDragPreview() }
        }
        .onChange(of: item) { _, updated in
            viewModel.update(item: updated)
            Task { cachedPreviewImage = await renderDragPreview() }
        }
    }

    private var iconView: some View {
        ZStack {
            if item.isStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.16))
                    .frame(width: ShelfMetrics.iconSize, height: ShelfMetrics.iconSize)
                    .offset(x: 3, y: -3)
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.22))
                    .frame(width: ShelfMetrics.iconSize, height: ShelfMetrics.iconSize)
                    .offset(x: 1.5, y: -1.5)
            }
            Image(nsImage: viewModel.thumbnail ?? viewModel.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: ShelfMetrics.iconSize, height: ShelfMetrics.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
        .frame(width: ShelfMetrics.iconSize + (item.isStack ? 4 : 0),
               height: ShelfMetrics.iconSize + (item.isStack ? 4 : 0))
    }

    private var stackListButton: some View {
        Button {
            showingStackList.toggle()
        } label: {
            Image(systemName: "list.bullet.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 14, height: 14)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var textView: some View {
        Text(item.displayName)
            .font(.system(size: item.isStack ? 10 : 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(item.isStack ? 1 : 2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(height: item.isStack ? 16 : 28, alignment: .top)
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
        var item: ShelfItem?
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
            guard let item else { return }
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag

            var draggingItems: [NSDraggingItem] = []
            for dragItem in itemsToDrag {
                let urls = ShelfStore.shared.resolveFileURLs(for: dragItem)
                if urls.isEmpty {
                    if let pasteboardItem = pasteboardItem(displayName: dragItem.displayName) {
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

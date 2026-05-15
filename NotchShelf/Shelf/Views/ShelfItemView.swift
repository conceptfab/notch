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

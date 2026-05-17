import AppKit
import SwiftUI

/// A single shelf item card: thumbnail, name, selection styling, and an AppKit drag
/// source for dragging the file back out into Finder.
struct ShelfItemView: View {
    let item: ShelfItem
    let keepsItemAfterExternalDrop: Bool
    let onToggleKeepsItemAfterExternalDrop: () -> Void
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var selection = ShelfSelection.shared
    @StateObject private var viewModel: ShelfItemViewModel
    @State private var cachedPreviewImage: NSImage?
    @State private var debouncedDropTarget = false
    @State private var dropTargetDebounceTask: Task<Void, Never>?
    @State private var dragPreviewTask: Task<Void, Never>?
    @State private var showingStackList = false

    private var isSelected: Bool { viewModel.isSelected }

    init(
        item: ShelfItem,
        keepsItemAfterExternalDrop: Bool = false,
        onToggleKeepsItemAfterExternalDrop: @escaping () -> Void = {}
    ) {
        self.item = item
        self.keepsItemAfterExternalDrop = keepsItemAfterExternalDrop
        self.onToggleKeepsItemAfterExternalDrop = onToggleKeepsItemAfterExternalDrop
        _viewModel = StateObject(wrappedValue: ShelfItemViewModel(item: item))
    }

    var body: some View {
        contentWithStackPresenter
    }

    @ViewBuilder
    private var contentWithStackPresenter: some View {
        if viewModel.viewData.isStack {
            itemContent.background(
                StackFileListPanelPresenter(
                    item: item,
                    viewModel: viewModel,
                    isPresented: $showingStackList,
                    windowModel: windowModel
                )
            )
        } else {
            itemContent
        }
    }

    private var itemContent: some View {
        ZStack(alignment: .bottom) {
            slotLayer

            DraggableClickHandler(
                item: item,
                viewModel: viewModel,
                displayName: viewModel.viewData.displayName,
                cachedPreviewImage: $cachedPreviewImage,
                onClick: { event, nsView in viewModel.handleClick(event: event, view: nsView) },
                onRightClick: { event, nsView in viewModel.handleRightClick(event: event, view: nsView) }
            )

            slotControlRow
                .position(x: ShelfMetrics.itemWidth / 2, y: ShelfMetrics.slotControlCenterY)
        }
        .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemHeight)
        .contentShape(Rectangle())
        .help(viewModel.viewData.displayName)
        .animation(ShelfAnimations.itemHover, value: debouncedDropTarget)
        .animation(ShelfAnimations.itemHover, value: isSelected)
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            dropTargetDebounceTask?.cancel()
            dropTargetDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            refreshDragPreview()
        }
        .onChange(of: item) { _, updated in
            viewModel.update(item: updated)
            refreshDragPreview()
        }
        .onDisappear {
            dropTargetDebounceTask?.cancel()
            dragPreviewTask?.cancel()
        }
    }

    private var slotLayer: some View {
        ZStack {
            slotContent
                .frame(width: ShelfMetrics.slotFrameSize, height: ShelfMetrics.slotFrameSize)
                .position(x: ShelfMetrics.itemWidth / 2, y: ShelfMetrics.slotFrameCenterY)
        }
        .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemHeight)
    }

    @ViewBuilder
    private var slotContent: some View {
        if viewModel.viewData.isStack {
            framedIconView
                .overlay(alignment: .top) {
                    countLabel
                        .offset(y: -ShelfMetrics.slotCountLabelHeight - ShelfMetrics.slotInnerSpacingTop)
                }
        } else {
            framedIconView
        }
    }

    @ViewBuilder
    private var countLabel: some View {
        if viewModel.viewData.isStack {
            Text("(\(viewModel.viewData.stackCount))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .frame(height: ShelfMetrics.slotCountLabelHeight)
                .accessibilityLabel("\(viewModel.viewData.stackCount) files")
        }
    }

    private var framedIconView: some View {
        iconView
            .offset(y: ShelfMetrics.slotIconVerticalOffset)
            .frame(width: ShelfMetrics.slotFrameSize,
                   height: ShelfMetrics.slotFrameSize)
            .background(backgroundView)
    }

    private var iconView: some View {
        ZStack {
            if viewModel.viewData.isStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(0.16))
                    .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                    .offset(x: 4, y: -4)
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(0.22))
                    .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                    .offset(x: 2, y: -2)
            }
            Image(nsImage: viewModel.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
        .frame(width: ShelfMetrics.iconSizeLarge + (viewModel.viewData.isStack ? 6 : 0),
               height: ShelfMetrics.iconSizeLarge + (viewModel.viewData.isStack ? 6 : 0))
    }

    @ViewBuilder
    private var slotControlRow: some View {
        if viewModel.viewData.isStack {
            HStack(spacing: 8) {
                stackListButton
                copyModeButton
            }
            .frame(width: ShelfMetrics.slotFrameSize, height: ShelfMetrics.itemToggleHeight)
        } else {
            copyModeButton
                .frame(width: ShelfMetrics.slotFrameSize, height: ShelfMetrics.itemToggleHeight)
        }
    }

    private var stackListButton: some View {
        Button {
            showingStackList.toggle()
        } label: {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: ShelfMetrics.itemToggleHeight, height: ShelfMetrics.itemToggleHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Show stack files")
        .accessibilityLabel("Show stack files")
    }

    private var copyModeButton: some View {
        Button(action: onToggleKeepsItemAfterExternalDrop) {
            Image(systemName: keepsItemAfterExternalDrop ? "plus.circle.fill" : "plus.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(keepsItemAfterExternalDrop ? Color.accentColor : .white.opacity(0.78))
                .frame(width: ShelfMetrics.itemToggleHeight, height: ShelfMetrics.itemToggleHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(keepsItemAfterExternalDrop ? "Copy from this slot" : "Move from this slot")
        .accessibilityLabel(keepsItemAfterExternalDrop ? "Copy from this slot" : "Move from this slot")
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
            thumbnail: viewModel.icon,
            displayName: viewModel.viewData.displayName
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? viewModel.icon
    }

    private func refreshDragPreview() {
        dragPreviewTask?.cancel()
        dragPreviewTask = Task { @MainActor in
            let rendered = await renderDragPreview()
            guard !Task.isCancelled else { return }
            cachedPreviewImage = rendered
        }
    }
}

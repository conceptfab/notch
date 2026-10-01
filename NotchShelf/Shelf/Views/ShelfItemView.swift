import AppKit
import SwiftUI

/// A single shelf item card: icon, selection styling, and an AppKit drag
/// source for dragging the file back out into Finder.
struct ShelfItemView: View {
    let item: ShelfItem
    let isSelected: Bool
    let keepsItemAfterExternalDrop: Bool
    let onToggleKeepsItemAfterExternalDrop: () -> Void
    @EnvironmentObject var windowModel: ShelfWindowModel
    @Environment(\.shelfLayout) private var layout
    @StateObject private var viewModel: ShelfItemViewModel
    @State private var cachedPreviewImage: NSImage?
    @State private var dragPreviewTask: Task<Void, Never>?
    @State private var showingStackList = false

    init(
        item: ShelfItem,
        isSelected: Bool = false,
        keepsItemAfterExternalDrop: Bool = false,
        onToggleKeepsItemAfterExternalDrop: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isSelected = isSelected
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
                .position(x: layout.slotSize / 2, y: layout.slotControlCenterY)
        }
        .frame(width: layout.slotSize, height: layout.cellHeight)
        .contentShape(Rectangle())
        .help(viewModel.viewData.displayName)
        .animation(ShelfAnimations.itemHover, value: isSelected)
        .onAppear {
            refreshDragPreview()
        }
        .onChange(of: item) { _, updated in
            viewModel.update(item: updated)
            refreshDragPreview()
        }
        .onDisappear {
            dragPreviewTask?.cancel()
        }
    }

    private var slotLayer: some View {
        ZStack {
            slotContent
                .frame(width: layout.slotSize, height: layout.slotSize)
                .position(x: layout.slotSize / 2, y: layout.slotFrameCenterY)
        }
        .frame(width: layout.slotSize, height: layout.cellHeight)
    }

    @ViewBuilder
    private var slotContent: some View {
        if viewModel.viewData.isStack {
            framedIconView
                .overlay(alignment: .topTrailing) {
                    countBadge
                }
        } else {
            framedIconView
        }
    }

    @ViewBuilder
    private var countBadge: some View {
        if viewModel.viewData.isStack {
            Text("\(viewModel.viewData.stackCount)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(minWidth: ShelfMetrics.slotCountBadgeHeight, minHeight: ShelfMetrics.slotCountBadgeHeight)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .offset(x: ShelfMetrics.slotCountBadgeOutset, y: -ShelfMetrics.slotCountBadgeOutset)
                .accessibilityLabel("\(viewModel.viewData.stackCount) files")
        }
    }

    private var framedIconView: some View {
        iconView
            .frame(width: layout.slotSize, height: layout.slotSize)
            .background(backgroundView)
    }

    private var iconView: some View {
        ZStack {
            if viewModel.viewData.isStack {
                RoundedRectangle(cornerRadius: layout.iconCornerRadius)
                    .fill(.white.opacity(0.16))
                    .frame(width: layout.iconSize, height: layout.iconSize)
                    .offset(x: 4, y: -4)
                RoundedRectangle(cornerRadius: layout.iconCornerRadius)
                    .fill(.white.opacity(0.22))
                    .frame(width: layout.iconSize, height: layout.iconSize)
                    .offset(x: 2, y: -2)
            }
            Image(nsImage: viewModel.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: layout.iconSize, height: layout.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: layout.iconCornerRadius))
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
        .frame(width: layout.iconSize + (viewModel.viewData.isStack ? 6 : 0),
               height: layout.iconSize + (viewModel.viewData.isStack ? 6 : 0))
    }

    @ViewBuilder
    private var slotControlRow: some View {
        if viewModel.viewData.isStack {
            HStack(spacing: stackControlSpacing) {
                stackListButton
                copyModeButton
            }
            .frame(width: layout.slotSize, height: ShelfMetrics.itemToggleHeight)
        } else {
            copyModeButton
                .frame(width: layout.slotSize, height: ShelfMetrics.itemToggleHeight)
        }
    }

    /// Narrow slots squeeze the two stack controls together so they stay under the frame.
    private var stackControlSpacing: CGFloat {
        Swift.min(8, Swift.max(0, layout.slotSize - ShelfMetrics.itemToggleHeight * 2))
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
        RoundedRectangle(cornerRadius: layout.slotCornerRadius, style: .continuous)
            .fill(backgroundColor)
            .stroke(strokeColor, lineWidth: strokeWidth)
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        return Color.clear
    }

    private var strokeColor: Color {
        if isSelected { return Color.accentColor.opacity(0.8) }
        return Color.clear
    }

    private var strokeWidth: CGFloat {
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

import AppKit
import SwiftUI

/// The shelf panel: a horizontally scrolling row of item cards, or a drop hint when
/// empty. Accepts file drops and supports Delete-to-remove on selected items.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    private let spacing: CGFloat = ShelfMetrics.itemSpacing

    var body: some View {
        panel
            .onDrop(of: [.fileURL], isTargeted: $windowModel.dragTargeting) { providers in
                handleDrop(providers: providers)
            }
            .focusable()
            .onDeleteCommand {
                for item in selection.selectedItems(in: store.items) {
                    ShelfActionService.remove(item)
                }
            }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        windowModel.dropEvent = true
        store.load(providers)
        return true
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                windowModel.dragTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.12),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7])
            )
            .overlay { content.padding(ShelfMetrics.contentPadding) }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    @ViewBuilder
    private var content: some View {
        if store.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "tray.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: ShelfMetrics.iconSize))
                Text("Schowek plików")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(store.items) { item in
                        ShelfItemView(item: item)
                    }
                }
                .frame(height: ShelfMetrics.itemHeight)
            }
            .scrollIndicators(.never)
        }
    }
}

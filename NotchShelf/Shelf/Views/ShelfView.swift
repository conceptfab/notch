import AppKit
import SwiftUI

/// The shelf panel: a horizontally scrolling row of file slots. Empty slots accept
/// drops and selected items can be removed with Delete.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    @State private var localDropTargeting = false
    private let spacing: CGFloat = ShelfMetrics.itemSpacing
    private var isVisuallyTargeted: Bool { windowModel.dragTargeting || localDropTargeting }

    var body: some View {
        panel
            .onDrop(of: [.fileURL], isTargeted: $localDropTargeting) { providers in
                handleDrop(providers: providers, slotIndex: nil)
            }
            .focusable()
            .onDeleteCommand {
                for item in selection.selectedItems(in: store.items) {
                    ShelfActionService.remove(item)
                }
            }
    }

    private func handleDrop(providers: [NSItemProvider], slotIndex: Int?) -> Bool {
        guard !selection.isDragging else { return false }
        windowModel.dropEvent = true
        store.load(providers, intoSlot: slotIndex)
        return true
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                Color.clear,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7])
            )
            .overlay { content.padding(ShelfMetrics.contentPadding) }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    private var content: some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                ForEach(Array(store.slots.enumerated()), id: \.element.id) { index, slot in
                    if let item = slot.item {
                        ShelfItemView(item: item)
                    } else {
                        ShelfSlotPlaceholderView(
                            isPanelTargeted: isVisuallyTargeted
                        ) { providers in
                            handleDrop(providers: providers, slotIndex: index)
                        }
                    }
                }
            }
            .frame(height: ShelfMetrics.itemHeight)
        }
        .scrollIndicators(.never)
    }
}

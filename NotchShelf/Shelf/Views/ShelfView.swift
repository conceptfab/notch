import AppKit
import SwiftUI

/// The shelf panel: a wrapping grid of file slots. Empty slots accept drops and
/// selected items can be removed with Delete. Drops elsewhere on the expanded shelf
/// are handled by `ShelfRevealContent` and reported through `isPanelDropTargeted`.
struct ShelfView: View {
    var isPanelDropTargeted = false

    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    @Environment(\.shelfLayout) private var layout
    @State private var dropZoneRGBA: RGBAColor = ShelfView.loadDropZoneColor()
    private var isVisuallyTargeted: Bool { windowModel.dragTargeting || isPanelDropTargeted }
    private var dropZoneColor: Color {
        let base = dropZoneRGBA.color
        return base.opacity(isVisuallyTargeted ? 0.95 : 0.68)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(layout.slotSize), spacing: ShelfMetrics.slotColumnSpacing, alignment: .top),
            count: layout.columnCount
        )
    }

    var body: some View {
        panel
            .focusable()
            .focusEffectDisabled()
            .onDeleteCommand {
                for item in selection.selectedItems(in: store.items) {
                    ShelfActionService.remove(item)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let next = Self.loadDropZoneColor()
                if next != dropZoneRGBA { dropZoneRGBA = next }
            }
    }

    private static func loadDropZoneColor() -> RGBAColor {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
            ?? RGBAColor.defaultDropZone.components
        return RGBAColor(components: components)
    }

    private func handleDrop(providers: [NSItemProvider], slotIndex: Int?) -> Bool {
        Self.acceptDrop(providers, intoSlot: slotIndex, windowModel: windowModel, store: store, selection: selection)
    }

    /// Shared drop entry point for slots and the surrounding shelf surface. Drags that
    /// started on the shelf itself are rejected so items are not re-added.
    static func acceptDrop(
        _ providers: [NSItemProvider],
        intoSlot slotIndex: Int?,
        windowModel: ShelfWindowModel,
        store: ShelfStore = .shared,
        selection: ShelfSelection = .shared
    ) -> Bool {
        guard !selection.isDragging else { return false }
        windowModel.dropEvent = true
        store.load(providers, intoSlot: slotIndex)
        return true
    }

    private var panel: some View {
        ZStack {
            content
                .padding(ShelfMetrics.slotGridOutlinePadding)

            RoundedRectangle(cornerRadius: layout.outlineCornerRadius)
                .strokeBorder(
                    dropZoneColor,
                    style: StrokeStyle(lineWidth: isVisuallyTargeted ? 2.5 : 2, lineCap: .round, dash: [7])
                )
                .allowsHitTesting(false)
        }
        .frame(width: layout.outlineSize.width, height: layout.outlineSize.height, alignment: .top)
        .contentShape(Rectangle())
        .animation(ShelfAnimations.outlineHover, value: isVisuallyTargeted)
        .onTapGesture { selection.clear() }
    }

    private var content: some View {
        LazyVGrid(columns: gridColumns, alignment: .center, spacing: ShelfMetrics.slotRowSpacing) {
            ForEach(Array(store.visibleSlots.enumerated()), id: \.element.id) { index, slot in
                if let item = slot.item {
                    ShelfItemView(
                        item: item,
                        isSelected: selection.isSelected(item.id),
                        keepsItemAfterExternalDrop: slot.keepsItemAfterExternalDrop
                    ) {
                        store.toggleKeepsItemAfterExternalDrop(forSlotID: slot.id)
                    }
                } else {
                    ShelfSlotPlaceholderView(
                        isPanelTargeted: isVisuallyTargeted
                    ) { providers in
                        handleDrop(providers: providers, slotIndex: index)
                    }
                }
            }
        }
    }
}

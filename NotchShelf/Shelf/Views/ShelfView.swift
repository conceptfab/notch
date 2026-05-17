import AppKit
import SwiftUI

/// The shelf panel: a wrapping grid of file slots. Empty slots accept drops and
/// selected items can be removed with Delete.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    @AppStorage(UserDefaultsKey.minSlotCount) private var configuredSlotCount = ShelfMetrics.defaultSlotCount
    @State private var localDropTargeting = false
    @State private var dropZoneRGBA: RGBAColor = ShelfView.loadDropZoneColor()
    private let spacing: CGFloat = ShelfMetrics.itemSpacing
    private var isVisuallyTargeted: Bool { windowModel.dragTargeting || localDropTargeting }
    private var dropZoneColor: Color {
        let base = dropZoneRGBA.color
        return base.opacity(isVisuallyTargeted ? 0.95 : 0.68)
    }

    private var rowCapacity: Int {
        ShelfMetrics.normalizedSlotCount(configuredSlotCount)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(ShelfMetrics.itemWidth), spacing: spacing, alignment: .top),
            count: rowCapacity
        )
    }

    private var rowCount: Int {
        let rows = Int(ceil(Double(Swift.max(store.visibleSlots.count, rowCapacity)) / Double(rowCapacity)))
        return Swift.max(rows, 1)
    }

    private var outlinedHeight: CGFloat {
        ShelfMetrics.slotGridOutlineHeight(rowCount: rowCount)
    }

    private var outlinedWidth: CGFloat {
        ShelfMetrics.slotGridOutlineWidth(columnCount: rowCapacity)
    }

    var body: some View {
        panel
            .onDrop(of: [.fileURL], isTargeted: $localDropTargeting) { providers in
                handleDrop(providers: providers, slotIndex: nil)
            }
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
        guard !selection.isDragging else { return false }
        windowModel.dropEvent = true
        store.load(providers, intoSlot: slotIndex)
        return true
    }

    private var panel: some View {
        ZStack(alignment: .topLeading) {
            content
                .padding(ShelfMetrics.contentPadding)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    dropZoneColor,
                    style: StrokeStyle(lineWidth: isVisuallyTargeted ? 2.5 : 2, lineCap: .round, dash: [7])
                )
                .frame(width: outlinedWidth, height: outlinedHeight)
                .padding(.top, ShelfMetrics.slotGridOutlineTop)
                .padding(.leading, ShelfMetrics.slotGridOutlineLeading)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .animation(ShelfAnimations.outlineHover, value: isVisuallyTargeted)
        .onTapGesture { selection.clear() }
    }

    private var content: some View {
        LazyVGrid(columns: gridColumns, alignment: .center, spacing: spacing) {
            ForEach(Array(store.visibleSlots.enumerated()), id: \.element.id) { index, slot in
                if let item = slot.item {
                    ShelfItemView(
                        item: item,
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
        .padding(.horizontal, ShelfMetrics.gridHorizontalInset)
    }
}

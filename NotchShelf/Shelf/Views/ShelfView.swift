import AppKit
import SwiftUI

/// The shelf panel: a horizontally scrolling row of item cards, or a drop hint when
/// empty. Accepts file drops and supports Delete-to-remove on selected items.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    private let spacing: CGFloat = 8

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
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay { content.padding() }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    @ViewBuilder
    private var content: some View {
        if store.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .symbolVariant(.fill)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, .gray)
                    .imageScale(.large)
                Text("Drop files here")
                    .foregroundStyle(.gray)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)
            }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(store.items) { item in
                        ShelfItemView(item: item)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

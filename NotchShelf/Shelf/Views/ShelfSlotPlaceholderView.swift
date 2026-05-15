import SwiftUI
import UniformTypeIdentifiers

struct ShelfSlotPlaceholderView: View {
    let isPanelTargeted: Bool
    let onDropFiles: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    private var isVisible: Bool { isTargeted || isPanelTargeted }
    private var strokeColor: Color {
        isTargeted ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.28)
    }
    private var slotSize: CGFloat { ShelfMetrics.iconSize * 2 }

    var body: some View {
        ZStack {
            if isVisible {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        strokeColor,
                        style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, lineCap: .round, dash: [8])
                    )
                    .frame(width: slotSize, height: slotSize)
            }
        }
            .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemHeight)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.12), value: isTargeted)
            .animation(.easeInOut(duration: 0.12), value: isPanelTargeted)
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted, perform: onDropFiles)
    }
}

import AppKit
import SwiftUI

/// Compact grid layout used when a stack has more than `stackListGridThreshold`
/// files. Every file remains visible; scrolling is only a final fallback.
struct StackFileGridView: View {
    let item: ShelfItem
    let entries: [StackMenuEntry]
    let viewModel: ShelfItemViewModel

    private let columns = [
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
            ForEach(entries, id: \.id) { entry in
                StackFileGridCellView(sourceItem: item, entry: entry, viewModel: viewModel)
            }
        }
        .padding(8)
    }
}

private struct StackFileGridCellView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let viewModel: ShelfItemViewModel
    @State private var icon: NSImage = NSWorkspace.shared.icon(for: .data)

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
            Text(entry.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 26, alignment: .top)
        }
        .frame(width: 60, height: 66)
        .contentShape(Rectangle())
        .overlay {
            StackFileDragHandler(sourceItem: sourceItem, entry: entry, previewImage: icon, viewModel: viewModel)
        }
        .onAppear { loadIcon() }
        .onChange(of: entry.id) { _, _ in loadIcon() }
    }

    private func loadIcon() {
        if let url = entry.fileURL {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .data)
        }
    }
}

import AppKit
import SwiftUI

struct StackFileRowView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    let viewModel: ShelfItemViewModel
    @State private var icon: NSImage = NSWorkspace.shared.icon(for: .data)

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(entry.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
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

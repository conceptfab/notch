import SwiftUI

struct StackFileListView: View {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var gridThreshold = 5
    @State private var entries: [StackMenuEntry] = []

    private var useGrid: Bool { entries.count > gridThreshold }

    var body: some View {
        ScrollView(.vertical) {
            if useGrid {
                StackFileGridView(item: item, entries: entries, viewModel: viewModel)
            } else {
                VStack(spacing: 2) {
                    ForEach(entries, id: \.id) { entry in
                        StackFileRowView(sourceItem: item, entry: entry, viewModel: viewModel)
                    }
                }
                .padding(6)
            }
        }
        .frame(maxHeight: 320)
        .scrollIndicators(.never)
        .background(Color.clear)
        .onAppear { resolveEntries() }
        .onChange(of: item) { _, _ in resolveEntries() }
    }

    private func resolveEntries() {
        entries = item.allBookmarkData.enumerated().map { index, data in
            let url = Bookmark(data: data).resolveURL()
            return StackMenuEntry(
                id: index,
                title: url?.lastPathComponent ?? "Unknown file",
                bookmarkData: data,
                fileURL: url
            )
        }
    }
}

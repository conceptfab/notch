import SwiftUI

struct ShelfClearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("ClearShelfIcon")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear shelf")
        .accessibilityLabel("Clear shelf")
    }
}

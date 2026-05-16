import SwiftUI

/// Status shown while the shelf is collapsed but still contains files.
struct CollapsedShelfStatusView: View {
    let fileCount: Int
    let shelfWidth: CGFloat
    let shelfHeight: CGFloat

    private var edgeInset: CGFloat {
        5
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: ShelfMetrics.collapsedStatusIconWidth, height: 22)
                .accessibilityLabel("NotchShelf shelf contains files")

            Spacer(minLength: 0)

            Text("\(fileCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .accessibilityLabel("\(fileCount) files on shelf")
        }
        .padding(.horizontal, edgeInset)
        .frame(width: shelfWidth, height: shelfHeight, alignment: .center)
    }
}

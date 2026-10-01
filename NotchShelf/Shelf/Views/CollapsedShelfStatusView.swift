import SwiftUI

/// Status shown while the shelf is collapsed but still contains files: a compact
/// strip directly below the notch, so the collapsed shape stays notch-wide.
struct CollapsedShelfStatusView: View {
    let fileCount: Int
    let shelfWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .accessibilityLabel("NotchShelf shelf contains files")

            Text("\(fileCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
                .accessibilityLabel("\(fileCount) files on shelf")
        }
        .frame(width: shelfWidth, height: ShelfMetrics.collapsedStatusRowHeight)
        .padding(.top, notchHeight)
    }
}

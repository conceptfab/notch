import AppKit
import SwiftUI

struct PreferencesSection<Content: View>: View {
    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, PreferencesPanelMetrics.rowHorizontalPadding)
            }

            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: PreferencesPanelMetrics.sectionCornerRadius)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
    }
}

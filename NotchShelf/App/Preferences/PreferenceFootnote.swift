import SwiftUI

struct PreferenceFootnote: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, PreferencesPanelMetrics.rowHorizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 9)
    }
}

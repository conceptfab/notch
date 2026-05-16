import SwiftUI

struct PreferencesPage<Content: View>: View {
    private let showsIndicators: Bool
    private let content: Content

    init(
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsIndicators) {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .frame(maxWidth: PreferencesPanelMetrics.contentWidth, alignment: .top)
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

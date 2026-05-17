import SwiftUI

struct PreferenceRow<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let titleLineLimit: Int
    private let trailing: Trailing

    init(_ title: LocalizedStringKey, titleLineLimit: Int = 2, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.titleLineLimit = titleLineLimit
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(titleLineLimit)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            trailing
                .controlSize(.mini)
        }
        .padding(.horizontal, PreferencesPanelMetrics.rowHorizontalPadding)
        .frame(minHeight: PreferencesPanelMetrics.rowMinHeight)
    }
}

import SwiftUI

struct PreferenceSliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let valueText: (Int) -> String
    @State private var doubleValue: Double

    init(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        valueText: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.valueText = valueText
        _doubleValue = State(initialValue: Double(value.wrappedValue))
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 12) {
                Slider(
                    value: $doubleValue,
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                ) {
                    Text(title)
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: PreferencesPanelMetrics.preferenceSliderWidth)
                .accessibilityValue(Text(valueText(value)))

                Text(valueText(value))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: PreferencesPanelMetrics.preferenceValueWidth, alignment: .trailing)
            }
        }
        .onChange(of: doubleValue) { _, newValue in
            let clamped = Swift.min(
                Swift.max(Int(newValue.rounded()), range.lowerBound),
                range.upperBound
            )
            if value != clamped { value = clamped }
        }
        .onChange(of: value) { _, newValue in
            let asDouble = Double(newValue)
            if doubleValue != asDouble { doubleValue = asDouble }
        }
    }
}

import SwiftUI

struct PreferenceSliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let valueText: (Int) -> String

    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        valueText: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.valueText = valueText
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 12) {
                Slider(
                    value: doubleValue,
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
    }

    private var doubleValue: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                value = Swift.min(
                    Swift.max(Int(newValue.rounded()), range.lowerBound),
                    range.upperBound
                )
            }
        )
    }
}

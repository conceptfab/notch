import SwiftUI

struct PreferenceDoubleSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String

    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        valueText: @escaping (Double) -> String
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 12) {
                Slider(value: $value, in: range, step: step) {
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
}

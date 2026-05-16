import SwiftUI

struct PreferenceStepperRow: View {
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
            HStack(spacing: 8) {
                Text(valueText(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)

                Stepper(title, value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}

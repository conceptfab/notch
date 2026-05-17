import SwiftUI

struct PreferenceSwitchToggleStyle: ToggleStyle {
    let accessibilityLabel: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        SwitchBody(configuration: configuration, accessibilityLabel: accessibilityLabel)
    }

    private struct SwitchBody: View {
        let configuration: Configuration
        let accessibilityLabel: LocalizedStringKey
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Button {
                let animation: Animation? = reduceMotion ? nil : .snappy(duration: 0.16)
                withAnimation(animation) {
                    configuration.isOn.toggle()
                }
            } label: {
                Capsule()
                    .fill(configuration.isOn ? Color.accentColor : Color(nsColor: .tertiaryLabelColor).opacity(0.26))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                            .padding(2)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(configuration.isOn ? 0.24 : 0.08), lineWidth: 0.75)
                    }
                    .frame(
                        width: PreferencesPanelMetrics.switchWidth,
                        height: PreferencesPanelMetrics.switchHeight
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
        }
    }
}

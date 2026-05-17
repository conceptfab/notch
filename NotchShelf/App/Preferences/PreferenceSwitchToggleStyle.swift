import SwiftUI

struct PreferenceSwitchToggleStyle: ToggleStyle {
    let accessibilityLabel: String

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
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

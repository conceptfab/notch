import AppKit
import SwiftUI

struct GeneralPreferencesView: View {
    @AppStorage(UserDefaultsKey.autoHideDelaySeconds) private var autoHideDelaySeconds = 1.5
    @AppStorage(UserDefaultsKey.copyOnDrag) private var copyOnDrag = false
    @AppStorage(UserDefaultsKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(UserDefaultsKey.glowOnSystemEvents) private var glowOnSystemEvents = true

    var body: some View {
        PreferencesPage {
            PreferencesSection("Behaviour") {
                PreferenceRow("Auto-hide delay") {
                    HStack(spacing: 12) {
                        Slider(value: $autoHideDelaySeconds, in: 0.5...5.0, step: 0.25) {
                            Text("Auto-hide delay")
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 132)
                        .accessibilityValue(Text(delayText))

                        Text(String(format: "%.2fs", autoHideDelaySeconds))
                            .font(.system(.caption, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                PreferenceDivider()
                PreferenceToggleRow(
                    "Always copy files when dragging within the app",
                    isOn: $copyOnDrag
                )

                PreferenceDivider()
                PreferenceToggleRow("Launch NotchShelf at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLoginService.shared.setEnabled(enabled)
                    }

                PreferenceDivider()
                PreferenceToggleRow(
                    "Flash notch glow on system notifications and events",
                    isOn: $glowOnSystemEvents
                )
            }

            PreferencesSection {
                HStack {
                    Spacer()

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit NotchShelf", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)

                    Spacer()
                }
                .padding(.horizontal, PreferencesPanelMetrics.rowHorizontalPadding)
                .frame(minHeight: PreferencesPanelMetrics.rowMinHeight)
            }
        }
    }

    private var delayText: String {
        String(format: "%.2f seconds", autoHideDelaySeconds)
    }
}

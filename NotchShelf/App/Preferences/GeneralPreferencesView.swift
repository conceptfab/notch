import AppKit
import SwiftUI

struct GeneralPreferencesView: View {
    @AppStorage(UserDefaultsKey.autoHideDelaySeconds) private var autoHideDelaySeconds = 1.5
    @AppStorage(UserDefaultsKey.copyOnDrag) private var copyOnDrag = false
    @AppStorage(UserDefaultsKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(UserDefaultsKey.glowOnSystemEvents) private var glowOnSystemEvents = true
    @AppStorage(UserDefaultsKey.playSoundOnSystemEventGlow) private var playSoundOnSystemEventGlow = false

    @State private var glowColor: Color = RGBAColor.defaultGlow.color

    var body: some View {
        PreferencesPage {
            PreferencesSection("Behaviour") {
                PreferenceDoubleSliderRow(
                    "Auto-hide delay",
                    value: $autoHideDelaySeconds,
                    in: 0.5...5.0,
                    step: 0.25,
                    valueText: { String(format: "%.2fs", $0) }
                )

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

                PreferenceDivider()
                PreferenceRow("Glow color") {
                    ColorPicker("Glow color", selection: $glowColor, supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 54)
                }

                PreferenceDivider()
                PreferenceToggleRow(
                    "Play sound with system-event glow",
                    isOn: $playSoundOnSystemEventGlow
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
        .onAppear {
            loadGlowColor()
        }
        .onChange(of: glowColor) { _, newValue in
            persist(glowColor: newValue)
        }
    }

    private func loadGlowColor() {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.glowColor) as? [Double]
            ?? RGBAColor.defaultGlow.components
        glowColor = RGBAColor(components: components, fallback: .defaultGlow).color
    }

    private func persist(glowColor color: Color) {
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return }
        let rgba = RGBAColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        UserDefaults.standard.set(rgba.components, forKey: UserDefaultsKey.glowColor)
    }
}

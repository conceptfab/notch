import AppKit
import SwiftUI

struct GeneralPreferencesView: View {
    @AppStorage(UserDefaultsKey.autoHideDelaySeconds) private var autoHideDelaySeconds = 1.5
    @AppStorage(UserDefaultsKey.copyOnDrag) private var copyOnDrag = false
    @AppStorage(UserDefaultsKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(UserDefaultsKey.glowOnSystemEvents) private var glowOnSystemEvents = false

    var body: some View {
        Form {
            Section("Behaviour") {
                LabeledContent("Auto-hide delay") {
                    HStack(spacing: 8) {
                        Slider(value: $autoHideDelaySeconds, in: 0.5...5.0, step: 0.25)
                            .frame(maxWidth: 200)
                        Text(String(format: "%.2fs", autoHideDelaySeconds))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 64, alignment: .trailing)
                    }
                }

                Toggle("Always copy files when dragging within the app", isOn: $copyOnDrag)
                Toggle("Launch NotchShelf at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLoginService.shared.setEnabled(enabled)
                    }
                Toggle("Flash notch glow on system events", isOn: $glowOnSystemEvents)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Quit NotchShelf", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

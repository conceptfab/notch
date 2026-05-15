import AppKit
import SwiftUI

struct PreferencesView: View {
    @AppStorage(UserDefaultsKey.copyOnDrag) private var copyOnDrag = false

    var body: some View {
        Form {
            Toggle("Always copy files when dragging off the shelf", isOn: $copyOnDrag)

            Divider()

            HStack {
                Spacer()
                Button("Quit NotchShelf", role: .destructive, action: quitApplication)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }

    private func quitApplication() {
        NSApp.terminate(nil)
    }
}

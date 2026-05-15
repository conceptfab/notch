import AppKit
import SwiftUI

struct PreferencesView: View {
    @AppStorage("copyOnDrag") private var copyOnDrag = false

    var body: some View {
        Form {
            Toggle("Zawsze kopiuj pliki przy przeciąganiu z półki", isOn: $copyOnDrag)

            Divider()

            HStack {
                Spacer()
                Button("Zamknij aplikację", role: .destructive, action: quitApplication)
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

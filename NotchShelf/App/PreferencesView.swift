import SwiftUI

struct PreferencesView: View {
    @State private var copyOnDrag = Preferences.shared.copyOnDrag

    var body: some View {
        Form {
            Toggle("Zawsze kopiuj pliki przy przeciąganiu z półki", isOn: $copyOnDrag)
                .onChange(of: copyOnDrag) { _, value in
                    Preferences.shared.copyOnDrag = value
                }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}

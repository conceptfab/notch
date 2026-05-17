import SwiftUI

struct PreferenceToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        PreferenceRow(title) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(PreferenceSwitchToggleStyle(accessibilityLabel: title))
                .labelsHidden()
        }
    }
}

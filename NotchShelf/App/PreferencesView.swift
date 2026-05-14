import SwiftUI

struct PreferencesView: View {
    var onClose: (() -> Void)?

    @State private var copyOnDrag = Preferences.shared.copyOnDrag

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Preferencje")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Spacer(minLength: 0)

                if let onClose {
                    Button("Zamknij", systemImage: "xmark") {
                        onClose()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                }
            }

            Toggle("Zawsze kopiuj pliki przy przeciąganiu z półki", isOn: $copyOnDrag)
                .onChange(of: copyOnDrag) { _, value in
                    Preferences.shared.copyOnDrag = value
                }
                .toggleStyle(.switch)
                .tint(.white.opacity(0.72))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}

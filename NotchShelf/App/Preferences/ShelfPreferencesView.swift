import SwiftUI

struct ShelfPreferencesView: View {
    @AppStorage(UserDefaultsKey.maxSlotCount) private var maxSlotCount = ShelfMetrics.defaultMaximumSlotCount
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var stackListGridThreshold = 5

    @State private var dropZoneColor: Color = RGBAColor.defaultDropZone.color

    var body: some View {
        Form {
            Section("Slots") {
                LabeledContent("Minimum visible slots", value: "\(ShelfMetrics.minimumSlotCount)")
                Stepper(value: $maxSlotCount, in: ShelfMetrics.minimumSlotCount...32) {
                    LabeledContent("Maximum slots", value: "\(maxSlotCount)")
                }
                Text("NotchShelf keeps two empty slots available, up to the maximum.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Drop zone") {
                ColorPicker("Outline color", selection: $dropZoneColor, supportsOpacity: true)
                Text("The dashed outline that pulses when files hover the shelf.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Stack list") {
                Stepper(value: $stackListGridThreshold, in: 3...20) {
                    LabeledContent("Switch to grid above", value: "\(stackListGridThreshold) files")
                }
                Text("All files in a stack are always reachable; the grid keeps them visible without scrolling.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear(perform: loadDropZoneColor)
        .onChange(of: dropZoneColor) { _, newValue in
            persist(dropZoneColor: newValue)
        }
    }

    private func loadDropZoneColor() {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
            ?? RGBAColor.defaultDropZone.components
        dropZoneColor = RGBAColor(components: components).color
    }

    private func persist(dropZoneColor color: Color) {
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return }
        let rgba = RGBAColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        UserDefaults.standard.set(rgba.components, forKey: UserDefaultsKey.dropZoneColor)
    }
}

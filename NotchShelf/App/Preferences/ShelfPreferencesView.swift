import SwiftUI

struct ShelfPreferencesView: View {
    @AppStorage(UserDefaultsKey.minSlotCount) private var slotCount = ShelfMetrics.defaultSlotCount
    @AppStorage(UserDefaultsKey.maxSlotCount) private var additionalRowCount = ShelfMetrics.defaultAdditionalRowCount
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var stackListGridThreshold = 5

    @State private var dropZoneColor: Color = RGBAColor.defaultDropZone.color

    var body: some View {
        Form {
            Section("Slots") {
                Stepper(value: $slotCount, in: ShelfMetrics.minimumSlotCount...ShelfMetrics.maximumSlotCount) {
                    LabeledContent("Slots", value: "\(slotCount)")
                }
                Stepper(value: $additionalRowCount, in: 0...ShelfMetrics.maximumAdditionalRowCount) {
                    LabeledContent("Additional rows", value: "\(additionalRowCount)")
                }
                Text("Additional rows appear only when the existing rows are occupied.")
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
        .onAppear {
            normalizeSlotPreferences()
            loadDropZoneColor()
        }
        .onChange(of: slotCount) { _, _ in
            normalizeSlotPreferences()
        }
        .onChange(of: additionalRowCount) { _, _ in
            normalizeSlotPreferences()
        }
        .onChange(of: dropZoneColor) { _, newValue in
            persist(dropZoneColor: newValue)
        }
    }

    private func normalizeSlotPreferences() {
        let normalizedSlotCount = ShelfMetrics.normalizedSlotCount(slotCount)
        if slotCount != normalizedSlotCount {
            slotCount = normalizedSlotCount
        }

        let normalizedAdditionalRowCount = ShelfMetrics.normalizedAdditionalRowCount(
            additionalRowCount,
            baseSlotCount: normalizedSlotCount
        )
        if additionalRowCount != normalizedAdditionalRowCount {
            additionalRowCount = normalizedAdditionalRowCount
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

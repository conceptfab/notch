import AppKit
import SwiftUI

struct ShelfPreferencesView: View {
    @AppStorage(UserDefaultsKey.minSlotCount) private var slotCount = ShelfMetrics.defaultSlotCount
    @AppStorage(UserDefaultsKey.maxSlotCount) private var additionalRowCount = ShelfMetrics.defaultAdditionalRowCount
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var stackListGridThreshold = 5

    @State private var dropZoneColor: Color = RGBAColor.defaultDropZone.color

    var body: some View {
        PreferencesPage(
            showsIndicators: true
        ) {
            PreferencesSection("Slots") {
                PreferenceStepperRow(
                    "Slots",
                    value: $slotCount,
                    in: ShelfMetrics.minimumSlotCount...ShelfMetrics.maximumSlotCount
                )

                PreferenceDivider()
                PreferenceStepperRow(
                    "Additional rows",
                    value: $additionalRowCount,
                    in: 0...ShelfMetrics.maximumAdditionalRowCount
                )

                PreferenceFootnote("Additional rows appear only when the existing rows are occupied.")
            }

            PreferencesSection("Drop zone") {
                PreferenceRow("Outline color") {
                    ColorPicker("Outline color", selection: $dropZoneColor, supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 54)
                }

                PreferenceFootnote("The dashed outline that pulses when files hover the shelf.")
            }

            PreferencesSection("Stack list") {
                PreferenceStepperRow(
                    "Switch to grid above",
                    value: $stackListGridThreshold,
                    in: 3...20,
                    valueText: { "\($0) files" }
                )

                PreferenceFootnote("All files in a stack are always reachable; the grid keeps them visible without scrolling.")
            }
        }
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

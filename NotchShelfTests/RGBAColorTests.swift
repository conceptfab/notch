import Testing
import SwiftUI
@testable import NotchShelf

@Suite("RGBAColor")
struct RGBAColorTests {
    @Test func roundTripsThroughComponents() {
        let color = RGBAColor(red: 0.0, green: 0.88, blue: 0.84, alpha: 1.0)
        let components = color.components
        let restored = RGBAColor(components: components)
        #expect(restored == color)
    }

    @Test func defaultMatchesLegacyTurquoise() {
        let defaultColor = RGBAColor.defaultDropZone
        #expect(defaultColor.red == 0.0)
        #expect(defaultColor.green == 0.88)
        #expect(defaultColor.blue == 0.84)
        #expect(defaultColor.alpha == 1.0)
    }

    @Test func componentsHasExactlyFourValues() {
        let color = RGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        #expect(color.components.count == 4)
        #expect(color.components == [0.1, 0.2, 0.3, 0.4])
    }

    @Test func malformedComponentsFallBackToDefault() {
        let restored = RGBAColor(components: [0.5, 0.5]) // too few values
        #expect(restored == .defaultDropZone)
    }

    @Test func oversizedComponentsFallBackToDefault() {
        let restored = RGBAColor(components: [0.1, 0.2, 0.3, 0.4, 0.5])
        #expect(restored == .defaultDropZone)
    }

    @Test func clampsOutOfRangeValues() {
        let color = RGBAColor(red: -0.5, green: 1.7, blue: 0.5, alpha: 2.0)
        #expect(color.red == 0.0)
        #expect(color.green == 1.0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1.0)
    }
}

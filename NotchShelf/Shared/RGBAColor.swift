import SwiftUI

/// Stable RGBA color value persisted as `[Double]` in `UserDefaults`.
/// Avoids `NSKeyedArchiver` so the stored representation is human-readable in
/// `defaults read` and trivially testable.
struct RGBAColor: Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let defaultDropZone = RGBAColor(red: 0.0, green: 0.88, blue: 0.84, alpha: 1.0)
    static let defaultGlow = RGBAColor(red: 0.09, green: 0.34, blue: 1.0, alpha: 1.0)

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    init(components: [Double], fallback: RGBAColor = .defaultDropZone) {
        guard components.count == 4 else {
            self = fallback
            return
        }
        self.init(
            red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components[3]
        )
    }

    var components: [Double] { [red, green, blue, alpha] }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func clamp(_ value: Double) -> Double {
        Swift.min(Swift.max(value, 0.0), 1.0)
    }
}

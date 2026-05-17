import SwiftUI

enum ShelfAnimations {
    /// Spring driving expand/collapse of the shelf shape.
    static let shelf: Animation = .spring(response: 0.32, dampingFraction: 0.86)
    /// Reduce-motion fallback for shelf shape transitions.
    static let shelfReduced: Animation = .easeInOut(duration: 0.14)

    /// Glow envelope phases.
    enum Glow {
        static let inDuration: Double = 0.18
        static let holdMillis: Int = 650
        static let outDuration: Double = 0.55
        static let reducedMotionHoldMillis: Int = 700
    }

    /// Drag-target / selection hover crossfade.
    static let itemHover: Animation = .easeInOut(duration: 0.1)
    /// Outline stroke-width swap when drop target changes.
    static let outlineHover: Animation = .easeInOut(duration: 0.12)
}

import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf.
enum ShelfMetrics {
    /// Extra width on each side of the physical notch when the empty shelf opens.
    static let sideExpansion: CGFloat = 24
    /// The maximum expanded shelf shape's size.
    static let expandedSize = CGSize(width: 520, height: 112)
    /// The panel stays fixed at this size and remains transparent outside the shape.
    static let windowSize = CGSize(width: 560, height: 140)
    static let iconSize: CGFloat = 24
    static let itemWidth: CGFloat = 56
    static let itemHeight: CGFloat = 58
    static let itemSpacing: CGFloat = 6
    static let contentPadding: CGFloat = 10
    static let menuButtonSize: CGFloat = 24
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    static let bottomCornerRadius: CGFloat = 16
}

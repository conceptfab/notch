import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf.
enum ShelfMetrics {
    /// The expanded shelf shape's size, the dark rounded area where items live.
    static let expandedSize = CGSize(width: 640, height: 200)
    /// The panel stays fixed at this size and remains transparent outside the shape.
    static let windowSize = CGSize(width: 720, height: 240)
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    static let bottomCornerRadius: CGFloat = 22
}

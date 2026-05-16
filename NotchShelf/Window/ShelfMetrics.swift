import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf.
enum ShelfMetrics {
    /// Minimum number of visible shelf slots. This is intentionally not user-configurable.
    static let minimumSlotCount = 5
    static let defaultMaximumSlotCount = 16
    /// Larger icon size used inside shelf item slots (no name label below).
    static let iconSizeLarge: CGFloat = 40
    /// Vertical space between the file count label and the icon.
    static let slotInnerSpacingTop: CGFloat = 2
    /// Vertical space between the icon and the bottom toggle row.
    static let slotInnerSpacingBottom: CGFloat = 4
    /// Height of the file-count label row at the top of each slot.
    static let slotCountLabelHeight: CGFloat = 12
    /// Extra width on each side of the physical notch when the empty shelf opens.
    static let sideExpansion: CGFloat = 60
    /// The maximum expanded shelf shape's size.
    static let expandedSize = CGSize(width: 1120, height: 220)
    /// The panel stays fixed at this size and remains transparent outside the shape.
    static let windowSize = CGSize(width: 1160, height: 250)
    static let itemWidth: CGFloat = 56
    static let itemHeight: CGFloat = 80
    static let itemToggleHeight: CGFloat = 16
    static let itemBodyHeight: CGFloat = itemHeight - itemToggleHeight - 2
    static let itemSpacing: CGFloat = 6
    static let contentPadding: CGFloat = 10
    /// Extra breathing room inside the dashed shelf outline around the fixed grid.
    static let gridHorizontalInset: CGFloat = 2
    /// Horizontal margin between the dashed shelf outline and the black shelf shape.
    static let shelfOuterHorizontalPadding: CGFloat = topCornerRadiusExpanded + 12
    static let shelfPanelBottomPadding: CGFloat = 13
    /// Vertical space reserved for the top chrome row (Clear button + Preferences button)
    /// so the dashed shelf outline never crosses underneath either icon.
    static let shelfTopChromeHeight: CGFloat = 48
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    /// Larger top corners when expanded, for more pronounced "ears".
    static let topCornerRadiusExpanded: CGFloat = 10
    static let bottomCornerRadius: CGFloat = 28
    /// Fixed width used by the collapsed shelf status icon.
    static let collapsedStatusIconWidth: CGFloat = 26
    /// Extra horizontal reach that makes file drags near the notch open the shelf.
    static let dragCatchHorizontalOutset: CGFloat = 160
    /// Downward reach from the notch, so the shelf opens before the pointer is pixel-perfect.
    static let dragCatchLowerOutset: CGFloat = 96
    /// Expanded shelf grace area to avoid flicker when the pointer crosses panel edges.
    static let dragExitHorizontalOutset: CGFloat = 48
    static let dragExitVerticalOutset: CGFloat = 40
}

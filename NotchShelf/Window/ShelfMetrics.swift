import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf. Sizes that depend on
/// the physical notch (slot size, shelf width and height) live in `ShelfLayout`.
enum ShelfMetrics {
    /// Minimum number of shelf slots in the base row. This many square slots span the notch width.
    static let minimumSlotCount = 4
    static let maximumSlotCount = 10
    static let defaultSlotCount = minimumSlotCount
    static let maximumAdditionalRowCount = 3
    static let defaultAdditionalRowCount = 2
    /// Bounds for the square slot frame derived from the notch width.
    static let minimumSlotFrameSize: CGFloat = 28
    static let maximumSlotFrameSize: CGFloat = 56
    /// Icon edge as a fraction of the slot frame edge.
    static let slotIconScale: CGFloat = 40.0 / 52.0
    /// Slot frame corner radius as a fraction of the slot frame edge.
    static let slotCornerRadiusScale: CGFloat = 12.0 / 52.0
    /// Icon corner radius as a fraction of the icon edge.
    static let iconCornerRadiusScale: CGFloat = 7.0 / 40.0
    /// Horizontal gap between neighbouring slot frames.
    static let slotColumnSpacing: CGFloat = 6
    /// Vertical gap between a row's control strip and the next row of slot frames.
    static let slotRowSpacing: CGFloat = slotColumnSpacing
    /// Stack file-count badge pinned to the slot frame's top-trailing corner.
    static let slotCountBadgeHeight: CGFloat = 14
    /// How far the badge pokes past the slot corner; stays inside the outline padding.
    static let slotCountBadgeOutset: CGFloat = 3
    /// Vertical space between the slot frame and its copy/list control row.
    static let slotControlSpacing: CGFloat = 3
    static let itemToggleHeight: CGFloat = 16
    /// Breathing room between the slot cells and the dashed drop-zone outline.
    static let slotGridOutlinePadding: CGFloat = 6
    /// Visible black frame between the dashed outline and the shelf shape.
    static let visibleBlackFramePadding: CGFloat = 8
    /// Bottom chrome row holding the Clear and Preferences buttons.
    static let bottomBarSpacing: CGFloat = 2
    static let bottomBarHeight: CGFloat = 28
    static let bottomBarBottomPadding: CGFloat = 6
    static let bottomBarButtonSize: CGFloat = 28
    /// The maximum expanded shelf shape's size.
    static let expandedSize = CGSize(width: 1120, height: 460)
    /// The panel stays fixed at this size and remains transparent outside the shape.
    static let windowSize = CGSize(width: 1160, height: 480)
    static let stackListPanelVerticalGap: CGFloat = 4
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    /// Larger top corners when expanded, for more pronounced "ears".
    static let topCornerRadiusExpanded: CGFloat = 10
    static let bottomCornerRadius: CGFloat = 28
    /// Extra collapsed notch height below the physical notch.
    static let collapsedHeightExtension: CGFloat = 5
    /// Height of the file-count strip shown below the notch while collapsed.
    static let collapsedStatusRowHeight: CGFloat = 18
    /// Extra horizontal reach that makes file drags near the notch open the shelf.
    static let dragCatchHorizontalOutset: CGFloat = 16
    /// Downward reach from the notch, so the shelf opens before the pointer is pixel-perfect.
    static let dragCatchLowerOutset: CGFloat = 8
    /// Tight hover activation area used while the shelf is collapsed.
    static let collapsedHoverHorizontalOutset: CGFloat = 8
    static let collapsedHoverLowerOutset: CGFloat = 4
    /// Expanded shelf grace area to avoid flicker when the pointer crosses panel edges.
    static let dragExitHorizontalOutset: CGFloat = 48
    static let dragExitVerticalOutset: CGFloat = 40

    static func normalizedSlotCount(_ value: Int) -> Int {
        guard value > 0 else { return defaultSlotCount }
        return Swift.min(Swift.max(value, minimumSlotCount), maximumSlotCount)
    }

    static func normalizedAdditionalRowCount(_ value: Int, baseSlotCount: Int) -> Int {
        guard value > maximumAdditionalRowCount else {
            return Swift.min(Swift.max(value, 0), maximumAdditionalRowCount)
        }

        // Older builds stored an absolute maximum slot count in this preference.
        // Convert that value to extra rows so existing installs land on the same capacity.
        let base = Swift.max(baseSlotCount, 1)
        let extraSlots = Swift.max(value - base, 0)
        let migratedRows = Int(ceil(Double(extraSlots) / Double(base)))
        return Swift.min(Swift.max(migratedRows, 0), maximumAdditionalRowCount)
    }
}

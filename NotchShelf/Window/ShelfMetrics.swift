import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf.
enum ShelfMetrics {
    /// Minimum number of shelf slots in the base row.
    static let minimumSlotCount = 5
    static let maximumSlotCount = 10
    static let defaultSlotCount = minimumSlotCount
    static let maximumAdditionalRowCount = 3
    static let defaultAdditionalRowCount = 2
    /// Larger icon size used inside shelf item slots (no name label below).
    static let iconSizeLarge: CGFloat = 40
    /// Square visual frame used for occupied and empty shelf slots.
    static let slotFrameSize: CGFloat = iconSizeLarge + 12
    /// File icon stays centered inside the slot frame.
    static let slotIconVerticalOffset: CGFloat = 0
    /// Vertical space between the file count label and the icon.
    static let slotInnerSpacingTop: CGFloat = 2
    /// Vertical space between the slot frame and the bottom toggle row.
    static let slotInnerSpacingBottom: CGFloat = 4
    /// Height of the file-count label row at the top of each slot.
    static let slotCountLabelHeight: CGFloat = 12
    /// Extra width on each side of the physical notch when the empty shelf opens.
    static let sideExpansion: CGFloat = 60
    /// The maximum expanded shelf shape's size.
    static let expandedSize = CGSize(width: 1120, height: 420)
    /// The panel stays fixed at this size and remains transparent outside the shape.
    static let windowSize = CGSize(width: 1160, height: 440)
    static let itemWidth: CGFloat = 56
    /// Horizontal padding around the fixed grid inside the shelf view.
    static let gridHorizontalInset: CGFloat = 2
    static let contentPadding: CGFloat = 10
    /// Horizontal inset from an item cell edge to the visible slot frame.
    static let slotFrameHorizontalInset: CGFloat = (itemWidth - slotFrameSize) / 2
    /// Breathing room between the slot frames and the dashed drop-zone outline.
    static let slotGridOutlinePadding: CGFloat = 8
    /// Visible black frame between the dashed outline and the shelf shape.
    static let visibleBlackFramePadding: CGFloat = 8
    static let itemToggleHeight: CGFloat = 16
    /// Gap from the item edge to the visual slot frame, matching the horizontal inset.
    static let slotFrameInset: CGFloat = gridHorizontalInset + (itemWidth - slotFrameSize) / 2
    static let slotGridOutlineLeading: CGFloat = contentPadding
        + gridHorizontalInset
        + slotFrameHorizontalInset
        - slotGridOutlinePadding
    static let slotGridOutlineTop: CGFloat = contentPadding
        + slotFrameInset
        - slotGridOutlinePadding
    static let slotGridOutlineBottom: CGFloat = visibleBlackFramePadding
    static let itemHeight: CGFloat = slotFrameSize
        + slotFrameInset * 2
        + slotGridOutlinePadding
        + slotInnerSpacingBottom
        + slotGridOutlineBottom
        + itemToggleHeight
    /// Shared vertical center for every slot frame inside an item cell.
    /// Mirrors the horizontal slot inset so the blue shelf outline has even spacing.
    static let slotFrameCenterY: CGFloat = slotFrameInset + slotFrameSize / 2
    /// Copy/list controls sit below the visual slot frame.
    static let slotControlCenterY: CGFloat = slotFrameCenterY
        + slotFrameSize / 2
        + slotGridOutlinePadding
        + slotInnerSpacingBottom
        + slotGridOutlineBottom
        + itemToggleHeight / 2
    static let itemBodyHeight: CGFloat = itemHeight - itemToggleHeight - 2
    static let itemSpacing: CGFloat = 6
    /// Extra margin outside the shelf view. The expanded shape's straight side is
    /// inset by topCornerRadiusExpanded, so this keeps the visible black frame at 8 px.
    static let shelfOuterHorizontalPadding: CGFloat = topCornerRadiusExpanded
        + visibleBlackFramePadding
        - slotGridOutlineLeading
    static let shelfPanelBottomPadding: CGFloat = 13
    static let stackListPanelVerticalGap: CGFloat = 4
    /// Vertical space reserved for the top chrome row (Clear button + Preferences button)
    /// so the dashed shelf outline never crosses underneath either icon.
    static let shelfTopChromeHeight: CGFloat = 48
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    /// Larger top corners when expanded, for more pronounced "ears".
    static let topCornerRadiusExpanded: CGFloat = 10
    static let bottomCornerRadius: CGFloat = 28
    /// Extra collapsed notch height below the physical notch.
    static let collapsedHeightExtension: CGFloat = 5
    /// Fixed width used by the collapsed shelf status icon.
    static let collapsedStatusIconWidth: CGFloat = 26
    /// Extra horizontal reach that makes file drags near the notch open the shelf.
    static let dragCatchHorizontalOutset: CGFloat = 64
    /// Downward reach from the notch, so the shelf opens before the pointer is pixel-perfect.
    static let dragCatchLowerOutset: CGFloat = 28
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

    static func maximumVisibleSlotCount(baseSlotCount: Int, additionalRows: Int) -> Int {
        normalizedSlotCount(baseSlotCount)
            * (1 + normalizedAdditionalRowCount(additionalRows, baseSlotCount: baseSlotCount))
    }

    static func slotGridOutlineWidth(columnCount: Int) -> CGFloat {
        let columns = Swift.max(columnCount, 1)
        return CGFloat(columns) * itemWidth
            + CGFloat(Swift.max(columns - 1, 0)) * itemSpacing
            - slotFrameHorizontalInset * 2
            + slotGridOutlinePadding * 2
    }

    static func slotGridOutlineHeight(rowCount: Int) -> CGFloat {
        let rows = Swift.max(rowCount, 1)
        return CGFloat(rows - 1) * (itemHeight + itemSpacing)
            + slotFrameSize
            + slotGridOutlinePadding * 2
    }
}

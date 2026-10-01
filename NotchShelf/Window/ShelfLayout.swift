import SwiftUI

/// Expanded shelf geometry derived from the physical notch. The minimum row of square
/// slots spans exactly the notch width; extra columns widen the shelf at the same slot
/// size. Content starts below the notch and the Clear/Preferences row sits at the bottom.
///
/// All vertical positions are measured from the top of the shelf shape (the screen edge).
struct ShelfLayout: Equatable {
    let columnCount: Int
    let rowCount: Int
    /// Edge of the square slot frame.
    let slotSize: CGFloat
    /// Width between the shape's straight sides (the shape adds expanded top-corner ears).
    let bodyWidth: CGFloat
    /// Height hidden behind the physical notch.
    let notchHeight: CGFloat

    init(notchWidth: CGFloat, notchHeight: CGFloat, columnCount: Int, rowCount: Int) {
        let minimumColumns = ShelfMetrics.minimumSlotCount
        let reserved = (ShelfMetrics.visibleBlackFramePadding + ShelfMetrics.slotGridOutlinePadding) * 2
            + CGFloat(minimumColumns - 1) * ShelfMetrics.slotColumnSpacing
        let fitted = ((notchWidth - reserved) / CGFloat(minimumColumns)).rounded(.down)

        self.columnCount = Swift.max(columnCount, 1)
        self.rowCount = Swift.max(rowCount, 1)
        self.notchHeight = notchHeight
        slotSize = Swift.min(Swift.max(fitted, ShelfMetrics.minimumSlotFrameSize), ShelfMetrics.maximumSlotFrameSize)

        let outlineWidth = CGFloat(self.columnCount) * slotSize
            + CGFloat(self.columnCount - 1) * ShelfMetrics.slotColumnSpacing
            + ShelfMetrics.slotGridOutlinePadding * 2
        bodyWidth = Swift.max(notchWidth, outlineWidth + ShelfMetrics.visibleBlackFramePadding * 2)
    }

    // MARK: Slot cell

    var iconSize: CGFloat { (slotSize * ShelfMetrics.slotIconScale).rounded() }
    var slotCornerRadius: CGFloat { slotSize * ShelfMetrics.slotCornerRadiusScale }
    var iconCornerRadius: CGFloat { iconSize * ShelfMetrics.iconCornerRadiusScale }
    /// One grid cell: the square slot frame with its copy/list control row underneath.
    var cellHeight: CGFloat {
        slotSize + ShelfMetrics.slotControlSpacing + ShelfMetrics.itemToggleHeight
    }
    var slotFrameCenterY: CGFloat { slotSize / 2 }
    var slotControlCenterY: CGFloat {
        slotSize + ShelfMetrics.slotControlSpacing + ShelfMetrics.itemToggleHeight / 2
    }

    // MARK: Grid and outline

    var gridWidth: CGFloat {
        CGFloat(columnCount) * slotSize + CGFloat(columnCount - 1) * ShelfMetrics.slotColumnSpacing
    }
    var gridHeight: CGFloat {
        CGFloat(rowCount) * cellHeight + CGFloat(rowCount - 1) * ShelfMetrics.slotRowSpacing
    }
    var outlineSize: CGSize {
        CGSize(
            width: gridWidth + ShelfMetrics.slotGridOutlinePadding * 2,
            height: gridHeight + ShelfMetrics.slotGridOutlinePadding * 2
        )
    }
    /// Concentric with the slot frames inside the outline.
    var outlineCornerRadius: CGFloat { slotCornerRadius + ShelfMetrics.slotGridOutlinePadding }
    var outlineTop: CGFloat { notchHeight + ShelfMetrics.visibleBlackFramePadding }

    // MARK: Bottom bar

    var bottomBarTop: CGFloat {
        outlineTop + outlineSize.height + ShelfMetrics.bottomBarSpacing
    }
    /// Spans the grid so each button is centred under the first or last slot column.
    var bottomBarWidth: CGFloat {
        gridWidth - slotSize + ShelfMetrics.bottomBarButtonSize
    }

    // MARK: Shape

    var shapeSize: CGSize {
        CGSize(
            width: bodyWidth + ShelfMetrics.topCornerRadiusExpanded * 2,
            height: bottomBarTop + ShelfMetrics.bottomBarHeight + ShelfMetrics.bottomBarBottomPadding
        )
    }
}

private struct ShelfLayoutKey: EnvironmentKey {
    static let defaultValue = ShelfLayout(
        notchWidth: 189,
        notchHeight: 32,
        columnCount: ShelfMetrics.defaultSlotCount,
        rowCount: 1
    )
}

extension EnvironmentValues {
    var shelfLayout: ShelfLayout {
        get { self[ShelfLayoutKey.self] }
        set { self[ShelfLayoutKey.self] = newValue }
    }
}

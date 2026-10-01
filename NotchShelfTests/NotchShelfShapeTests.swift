import SwiftUI
import Testing
@testable import NotchShelf

@Test func notchShelfShapeProducesNonEmptyPath() {
    let shape = NotchShelfShape(topCornerRadius: 6, bottomCornerRadius: 20)
    let path = shape.path(in: CGRect(x: 0, y: 0, width: 600, height: 200))
    #expect(path.isEmpty == false)
    #expect(path.boundingRect.width > 0)
    #expect(path.boundingRect.height > 0)
}

@Test func shelfMetricsExpandedIsLargerThanWindowPadding() {
    #expect(ShelfMetrics.expandedSize.width > 0)
    #expect(ShelfMetrics.expandedSize.height > 0)
    #expect(ShelfMetrics.windowSize.width >= ShelfMetrics.expandedSize.width)
    #expect(ShelfMetrics.windowSize.height >= ShelfMetrics.expandedSize.height)
}

@Test func minimumRowOfSquareSlotsSpansNotchWidth() {
    for notchWidth in [189.0, 255.0] as [CGFloat] {
        let layout = ShelfLayout(
            notchWidth: notchWidth,
            notchHeight: 38,
            columnCount: ShelfMetrics.minimumSlotCount,
            rowCount: 1
        )
        let usedWidth = layout.outlineSize.width + ShelfMetrics.visibleBlackFramePadding * 2

        #expect(layout.bodyWidth == notchWidth)
        #expect(usedWidth <= notchWidth)
        // Rounding the slot edge down leaves less than one point per column unused.
        #expect(notchWidth - usedWidth < CGFloat(ShelfMetrics.minimumSlotCount))
    }
}

@Test func slotSizeFollowsNotchWidth() {
    let wide = ShelfLayout(notchWidth: 255, notchHeight: 44, columnCount: 4, rowCount: 1)
    let narrow = ShelfLayout(notchWidth: 189, notchHeight: 32, columnCount: 4, rowCount: 1)

    #expect(wide.slotSize == 52)
    #expect(narrow.slotSize == 35)
    #expect(wide.iconSize == 40)
}

@Test func slotSizeStaysWithinBounds() {
    let tiny = ShelfLayout(notchWidth: 60, notchHeight: 32, columnCount: 4, rowCount: 1)
    let huge = ShelfLayout(notchWidth: 600, notchHeight: 32, columnCount: 4, rowCount: 1)

    #expect(tiny.slotSize == ShelfMetrics.minimumSlotFrameSize)
    #expect(huge.slotSize == ShelfMetrics.maximumSlotFrameSize)
}

@Test func extraColumnsWidenShelfAtSameSlotSize() {
    let base = ShelfLayout(notchWidth: 189, notchHeight: 32, columnCount: 4, rowCount: 1)
    let wider = ShelfLayout(notchWidth: 189, notchHeight: 32, columnCount: 6, rowCount: 1)

    #expect(wider.slotSize == base.slotSize)
    #expect(wider.bodyWidth == wider.outlineSize.width + ShelfMetrics.visibleBlackFramePadding * 2)
    #expect(wider.bodyWidth > base.bodyWidth)
}

@Test func slotControlsSitBelowSlotFrameInsideCell() {
    let layout = ShelfLayout(notchWidth: 189, notchHeight: 32, columnCount: 4, rowCount: 1)
    let slotBottom = layout.slotFrameCenterY + layout.slotSize / 2
    let controlTop = layout.slotControlCenterY - ShelfMetrics.itemToggleHeight / 2
    let controlBottom = layout.slotControlCenterY + ShelfMetrics.itemToggleHeight / 2

    #expect(controlTop >= slotBottom)
    #expect(controlBottom <= layout.cellHeight)
}

@Test func shelfContentStartsBelowNotchAndBottomBarFitsInsideShape() {
    for rows in 1...(1 + ShelfMetrics.maximumAdditionalRowCount) {
        let layout = ShelfLayout(notchWidth: 189, notchHeight: 32, columnCount: 4, rowCount: rows)
        let outlineBottom = layout.outlineTop + layout.outlineSize.height
        let barBottom = layout.bottomBarTop + ShelfMetrics.bottomBarHeight

        #expect(layout.outlineTop >= layout.notchHeight)
        #expect(layout.bottomBarTop >= outlineBottom)
        #expect(barBottom <= layout.shapeSize.height)
        #expect(layout.bottomBarWidth >= layout.gridWidth - layout.slotSize)
    }
}

@Test func largestShelfFitsWithinExpandedBounds() {
    let layout = ShelfLayout(
        notchWidth: 600,
        notchHeight: 44,
        columnCount: ShelfMetrics.maximumSlotCount,
        rowCount: 1 + ShelfMetrics.maximumAdditionalRowCount
    )

    #expect(layout.shapeSize.width <= ShelfMetrics.expandedSize.width)
    #expect(layout.shapeSize.height <= ShelfMetrics.expandedSize.height)
}

@Test func stackCountBadgeStaysInsideOutlineAndColumnGap() {
    #expect(ShelfMetrics.slotCountBadgeOutset < ShelfMetrics.slotGridOutlinePadding)
    #expect(ShelfMetrics.slotCountBadgeOutset * 2 <= ShelfMetrics.slotColumnSpacing)
}

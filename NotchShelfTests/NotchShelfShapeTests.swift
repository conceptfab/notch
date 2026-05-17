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

@Test func shelfMetricControlsSitBelowSlotFrame() {
    let slotBottom = ShelfMetrics.slotFrameCenterY + ShelfMetrics.slotFrameSize / 2
    let controlTop = ShelfMetrics.slotControlCenterY - ShelfMetrics.itemToggleHeight / 2
    let controlBottom = ShelfMetrics.slotControlCenterY + ShelfMetrics.itemToggleHeight / 2

    #expect(controlTop >= slotBottom + ShelfMetrics.slotInnerSpacingBottom)
    #expect(controlBottom <= ShelfMetrics.itemHeight)
}

@Test func shelfOutlinePadsSlotFramesEvenly() {
    let columns = ShelfMetrics.minimumSlotCount
    let expectedWidth = CGFloat(columns) * ShelfMetrics.itemWidth
        + CGFloat(columns - 1) * ShelfMetrics.itemSpacing
        - ShelfMetrics.slotFrameHorizontalInset * 2
        + ShelfMetrics.slotGridOutlinePadding * 2
    let slotFrameTop = ShelfMetrics.contentPadding
        + ShelfMetrics.slotFrameCenterY
        - ShelfMetrics.slotFrameSize / 2
    let slotFrameBottom = ShelfMetrics.contentPadding
        + ShelfMetrics.slotFrameCenterY
        + ShelfMetrics.slotFrameSize / 2

    #expect(ShelfMetrics.slotGridOutlineWidth(columnCount: columns) == expectedWidth)
    #expect(ShelfMetrics.slotGridOutlineHeight(rowCount: 1) == ShelfMetrics.slotFrameSize + ShelfMetrics.slotGridOutlinePadding * 2)
    #expect(ShelfMetrics.slotGridOutlineTop + ShelfMetrics.slotGridOutlinePadding == slotFrameTop)
    #expect(
        ShelfMetrics.slotGridOutlineTop
            + ShelfMetrics.slotGridOutlineHeight(rowCount: 1)
            - ShelfMetrics.slotGridOutlinePadding
        == slotFrameBottom
    )
}

@Test func shelfBlackMarginsMatchAroundOutline() {
    let sideMargin = ShelfMetrics.shelfOuterHorizontalPadding
        + ShelfMetrics.slotGridOutlineLeading
        - ShelfMetrics.topCornerRadiusExpanded

    #expect(ShelfMetrics.slotGridOutlineBottom == sideMargin)
    #expect(sideMargin == ShelfMetrics.visibleBlackFramePadding)
}

@Test func shelfControlsSitOutsideExpandedBlackShape() {
    let blackShapeBottom = ShelfMetrics.shelfTopChromeHeight
        + ShelfMetrics.slotGridOutlineTop
        + ShelfMetrics.slotGridOutlineHeight(rowCount: 1)
        + ShelfMetrics.slotGridOutlineBottom
    let controlTop = ShelfMetrics.shelfTopChromeHeight
        + ShelfMetrics.contentPadding
        + ShelfMetrics.slotControlCenterY
        - ShelfMetrics.itemToggleHeight / 2

    #expect(controlTop >= blackShapeBottom)
}

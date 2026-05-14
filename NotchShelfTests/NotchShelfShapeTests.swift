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

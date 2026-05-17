import Foundation
import Testing
@testable import NotchShelf

@Test func notchGeometryComputesCenteredRectFromAuxAreas() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                                 auxLeftWidth: 620, auxRightWidth: 620)
    #expect(geometry.hasNotch == true)
    #expect(geometry.notchWidth == CGFloat(1512 - 620 - 620 + 4))
    #expect(geometry.notchHeight == 38)
    #expect(geometry.notchRect.midX == screen.midX)
    #expect(geometry.notchRect.maxY == screen.maxY)
    #expect(geometry.notchRect.height == 38)
}

@Test func notchGeometryUsesAuxAreaEdgeForAsymmetricRects() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                                 auxLeftWidth: 600, auxRightWidth: 650)
    #expect(geometry.notchWidth == CGFloat(1512 - 600 - 650 + 4))
    #expect(geometry.notchRect.minX == 598)
    #expect(geometry.notchRect.midX != screen.midX)
}

@Test func notchGeometryFallsBackWhenNoAuxAreas() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 0,
                                 auxLeftWidth: nil, auxRightWidth: nil)
    #expect(geometry.hasNotch == false)
    #expect(geometry.notchWidth == 185)
    #expect(geometry.notchHeight == 32)
}

@Test func currentReturnsZeroEquivalentGeometryWhenNoScreensAvailable() {
    let geometry = NotchGeometry(
        screenFrame: .zero,
        safeAreaTop: 0,
        auxLeftWidth: nil,
        auxRightWidth: nil
    )
    #expect(geometry.notchRect == CGRect(x: -92.5, y: -32, width: 185, height: 32))
    #expect(geometry.hasNotch == false)
}

@Test func notchGeometryContainsPointInsideAndOutside() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                                 auxLeftWidth: 620, auxRightWidth: 620)
    #expect(geometry.contains(CGPoint(x: screen.midX, y: 970)) == true)
    #expect(geometry.contains(CGPoint(x: 10, y: 970)) == false)
    #expect(geometry.contains(CGPoint(x: screen.midX, y: 500)) == false)
}

@Test func dragCatchRegionExpandsNotchDownwardAndSideways() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                                 auxLeftWidth: 620, auxRightWidth: 620)

    let catchRegion = geometry.dragCatchRegion()

    #expect(catchRegion.maxY == geometry.notchRect.maxY)
    #expect(catchRegion.width == geometry.notchRect.width + 32)
    #expect(catchRegion.height == geometry.notchRect.height + 8)
    #expect(catchRegion.contains(CGPoint(x: geometry.notchRect.midX, y: geometry.notchRect.minY - 6)))
    #expect(catchRegion.contains(CGPoint(x: geometry.notchRect.minX - 12, y: geometry.notchRect.midY)))
    #expect(catchRegion.contains(CGPoint(x: geometry.notchRect.minX - 24, y: geometry.notchRect.midY)) == false)
    #expect(catchRegion.contains(CGPoint(x: geometry.notchRect.midX, y: geometry.notchRect.minY - 16)) == false)
}

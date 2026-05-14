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

@Test func notchGeometryContainsPointInsideAndOutside() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                                 auxLeftWidth: 620, auxRightWidth: 620)
    #expect(geometry.contains(CGPoint(x: screen.midX, y: 970)) == true)
    #expect(geometry.contains(CGPoint(x: 10, y: 970)) == false)
    #expect(geometry.contains(CGPoint(x: screen.midX, y: 500)) == false)
}

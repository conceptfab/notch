import SwiftUI

/// The continuous notch-into-shelf shape: a downward rectangle whose upper-inner
/// corners curve gently and whose lower corners are more rounded.
struct NotchShelfShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = ShelfMetrics.topCornerRadius,
         bottomCornerRadius: CGFloat = ShelfMetrics.bottomCornerRadius) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tcr = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bcr = min(bottomCornerRadius, rect.width / 2, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tcr, y: rect.minY + tcr),
            control: CGPoint(x: rect.minX + tcr, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + tcr, y: rect.maxY - bcr))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tcr + bcr, y: rect.maxY),
            control: CGPoint(x: rect.minX + tcr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tcr - bcr, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tcr, y: rect.maxY - bcr),
            control: CGPoint(x: rect.maxX - tcr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tcr, y: rect.minY + tcr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tcr, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

import SwiftUI

/// A short-lived launch accent drawn around the notch panel outline.
struct StartupGlowView: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let glowColor: Color

    var body: some View {
        ZStack {
            glowStroke(lineWidth: 3, opacity: 0.9, blurRadius: 2)
            glowStroke(lineWidth: 7, opacity: 0.46, blurRadius: 7)
            glowStroke(lineWidth: 13, opacity: 0.2, blurRadius: 15)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glowStroke(lineWidth: CGFloat, opacity: Double, blurRadius: CGFloat) -> some View {
        NotchShelfGlowEdgesShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
        .stroke(
            LinearGradient(
                colors: [
                    glowColor.opacity(opacity),
                    glowColor.opacity(opacity * 0.75),
                    glowColor.opacity(opacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            lineWidth: lineWidth
        )
        .blur(radius: blurRadius)
    }
}

private struct NotchShelfGlowEdgesShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

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
        return path
    }
}

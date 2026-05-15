import SwiftUI

/// A short-lived launch accent drawn around the notch panel outline.
struct StartupGlowView: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

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
        NotchShelfShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
        .stroke(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.34, blue: 1.0).opacity(opacity),
                    Color(red: 0.0, green: 0.62, blue: 1.0).opacity(opacity * 0.75),
                    Color(red: 0.09, green: 0.34, blue: 1.0).opacity(opacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            lineWidth: lineWidth
        )
        .blur(radius: blurRadius)
    }
}

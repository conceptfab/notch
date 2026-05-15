import SwiftUI

struct ShelfClearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BroomIcon()
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear shelf")
        .accessibilityLabel("Clear shelf")
    }
}

private struct BroomIcon: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let strokeWidth = max(1.2, size * 0.1)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: size * 0.75, y: size * 0.12))
                    path.addLine(to: CGPoint(x: size * 0.34, y: size * 0.55))
                }
                .stroke(
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: size * 0.3, y: size * 0.54))
                    path.addLine(to: CGPoint(x: size * 0.57, y: size * 0.82))
                    path.addLine(to: CGPoint(x: size * 0.24, y: size * 0.92))
                    path.addLine(to: CGPoint(x: size * 0.12, y: size * 0.8))
                    path.closeSubpath()
                }
                .fill()

                Path { path in
                    path.move(to: CGPoint(x: size * 0.22, y: size * 0.67))
                    path.addLine(to: CGPoint(x: size * 0.39, y: size * 0.84))
                    path.move(to: CGPoint(x: size * 0.15, y: size * 0.8))
                    path.addLine(to: CGPoint(x: size * 0.27, y: size * 0.92))
                }
                .stroke(
                    style: StrokeStyle(
                        lineWidth: max(0.8, strokeWidth * 0.48),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

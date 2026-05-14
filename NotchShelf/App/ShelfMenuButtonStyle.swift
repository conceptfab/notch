import SwiftUI

struct ShelfMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.7 : 0.92))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? .white.opacity(0.08) : .clear)
            .contentShape(Rectangle())
    }
}

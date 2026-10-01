import SwiftUI

/// Keeps the shelf controls mounted while the notch shape animates, so the content
/// slides out from the screen edge instead of appearing after the window opens.
struct ShelfRevealContent: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel

    let layout: ShelfLayout
    let reduceMotion: Bool
    let clearShelf: () -> Void
    let showPreferences: () -> Void

    @State private var isDropTargeted = false

    private var isExpanded: Bool {
        windowModel.expansion == .expanded
    }

    private var revealOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return isExpanded ? 0 : -layout.outlineTop
    }

    private var revealOpacity: Double {
        reduceMotion && !isExpanded ? 0 : 1
    }

    private var revealMaskHeight: CGFloat {
        let contentHeight = layout.shapeSize.height
        guard !reduceMotion else { return contentHeight }
        return isExpanded ? contentHeight : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ShelfView(isPanelDropTargeted: isDropTargeted)
                .padding(.top, layout.outlineTop)

            bottomBar
                .padding(.top, ShelfMetrics.bottomBarSpacing)
        }
        .frame(width: layout.shapeSize.width, height: layout.shapeSize.height, alignment: .top)
        // The whole expanded shape accepts drops, not just the dashed outline.
        .contentShape(NotchShelfShape(
            topCornerRadius: ShelfMetrics.topCornerRadiusExpanded,
            bottomCornerRadius: ShelfMetrics.bottomCornerRadius
        ))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            ShelfView.acceptDrop(providers, intoSlot: nil, windowModel: windowModel)
        }
        .environment(\.shelfLayout, layout)
        .offset(y: revealOffset)
        .opacity(revealOpacity)
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: revealMaskHeight, alignment: .top)
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ShelfClearButton(action: clearShelf)
            Spacer(minLength: 0)
            Button("Preferences", systemImage: "gearshape.fill", action: showPreferences)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: ShelfMetrics.bottomBarButtonSize, height: ShelfMetrics.bottomBarButtonSize)
                .contentShape(Rectangle())
                .help("Preferences")
                .accessibilityLabel("Preferences")
        }
        .frame(width: layout.bottomBarWidth, height: ShelfMetrics.bottomBarHeight)
    }
}

import SwiftUI

/// Keeps the shelf controls mounted while the notch shape animates, so the content
/// slides out from the screen edge instead of appearing after the window opens.
struct ShelfRevealContent: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel

    let preferencesButtonTopPadding: CGFloat
    let hiddenOffset: CGFloat
    let contentHeight: CGFloat
    let panelWidth: CGFloat
    let reduceMotion: Bool
    let clearShelf: () -> Void
    let showPreferences: () -> Void

    private var isExpanded: Bool {
        windowModel.expansion == .expanded
    }

    private var revealOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return isExpanded ? 0 : -hiddenOffset
    }

    private var revealOpacity: Double {
        reduceMotion && !isExpanded ? 0 : 1
    }

    private var revealMaskHeight: CGFloat {
        guard !reduceMotion else { return contentHeight }
        return isExpanded ? contentHeight : 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            ShelfView()
                .environmentObject(windowModel)
                .frame(width: panelWidth)
                .padding(.top, ShelfMetrics.shelfTopChromeHeight)
                .padding(.bottom, ShelfMetrics.shelfPanelBottomPadding)
                .zIndex(1)

            topBar
                .padding(.top, preferencesButtonTopPadding)
                .zIndex(2)
        }
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

    private var topBar: some View {
        VStack {
            HStack {
                ShelfClearButton(action: clearShelf)
                Spacer()
                Button("Preferences", systemImage: "gearshape.fill", action: showPreferences)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .help("Preferences")
                    .accessibilityLabel("Preferences")
            }
            .frame(width: panelWidth)
            Spacer()
        }
    }
}

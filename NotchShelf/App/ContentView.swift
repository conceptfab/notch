import SwiftUI
import AppKit

/// Root view hosted inside the notch panel. Draws the continuous notch-into-shelf
/// shape sized from `ShelfWindowModel.expansion`, with shelf content layered inside
/// the shape when expanded.
struct ContentView: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var store = ShelfStore.shared
    @AppStorage(UserDefaultsKey.minSlotCount) private var configuredSlotCount = ShelfMetrics.defaultSlotCount
    @State private var isStartupGlowVisible = false
    @State private var didPlayStartupGlow = false
    @State private var glowTask: Task<Void, Never>?

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var hasItems: Bool { !store.items.isEmpty }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: collapsedShapeWidth, height: geometry.notchHeight)
        case .expanded:
            return expandedShapeSize
        }
    }

    private var collapsedShapeWidth: CGFloat {
        geometry.notchWidth + geometry.notchHeight * 2
    }

    private var expandedShapeSize: CGSize {
        let rowCapacity = renderedRowCapacity
        let rowCount = renderedRowCount
        let rowHeight = CGFloat(rowCount) * ShelfMetrics.itemHeight
            + CGFloat(Swift.max(rowCount - 1, 0)) * ShelfMetrics.itemSpacing
        let chromeHeight = ShelfMetrics.shelfTopChromeHeight
            + ShelfMetrics.shelfPanelBottomPadding
        let height = chromeHeight + rowHeight

        let rowWidth = shelfPanelWidth(for: rowCapacity)
            + ShelfMetrics.shelfOuterHorizontalPadding * 2
        return CGSize(
            width: Swift.min(ShelfMetrics.expandedSize.width, Swift.max(geometry.notchWidth, rowWidth)),
            height: Swift.min(ShelfMetrics.expandedSize.height, height)
        )
    }

    private var renderedSlotCount: Int {
        Swift.max(store.visibleSlots.count, renderedRowCapacity)
    }

    private var renderedRowCapacity: Int {
        ShelfMetrics.normalizedSlotCount(configuredSlotCount)
    }

    private var renderedRowCount: Int {
        let rows = Int(ceil(Double(renderedSlotCount) / Double(renderedRowCapacity)))
        return Swift.max(rows, 1)
    }

    private func shelfPanelWidth(for slotCount: Int) -> CGFloat {
        let columns = ShelfMetrics.normalizedSlotCount(slotCount)
        return CGFloat(columns) * ShelfMetrics.itemWidth
            + CGFloat(Swift.max(columns - 1, 0)) * ShelfMetrics.itemSpacing
            + ShelfMetrics.contentPadding * 2
            + ShelfMetrics.gridHorizontalInset * 2
    }

    private var currentTopCornerRadius: CGFloat {
        windowModel.expansion == .expanded
            ? ShelfMetrics.topCornerRadiusExpanded
            : ShelfMetrics.topCornerRadius
    }

    private var preferencesButtonTopPadding: CGFloat {
        4
    }

    private var shelfAnimation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.14)
        }
        return .spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.08)
    }

    private struct AnimationSignature: Hashable {
        let expansion: ShelfWindowModel.Expansion
        let itemCount: Int
        let totalFileCount: Int
    }

    private var animationSignature: AnimationSignature {
        AnimationSignature(
            expansion: windowModel.expansion,
            itemCount: store.items.count,
            totalFileCount: store.totalFileCount
        )
    }

    var body: some View {
        let currentShapeSize = shapeSize
        let expandedContentSize = expandedShapeSize
        ZStack(alignment: .top) {
            if isStartupGlowVisible {
                StartupGlowView(
                    topCornerRadius: currentTopCornerRadius,
                    bottomCornerRadius: windowModel.expansion == .expanded
                        ? ShelfMetrics.bottomCornerRadius : 8
                )
                    .frame(width: currentShapeSize.width, height: currentShapeSize.height)
                    .transition(.opacity)
                    .zIndex(0)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    NotchShelfShape(
                        topCornerRadius: currentTopCornerRadius,
                        bottomCornerRadius: windowModel.expansion == .expanded
                            ? ShelfMetrics.bottomCornerRadius : 8
                    )
                    .fill(Color.black)
                    .overlay(alignment: .top) {
                        // Seamless connection to top screen edge
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 1)
                            .padding(.horizontal, currentTopCornerRadius)
                    }

                    ShelfRevealContent(
                        preferencesButtonTopPadding: preferencesButtonTopPadding,
                        hiddenOffset: ShelfMetrics.shelfTopChromeHeight,
                        contentHeight: expandedContentSize.height,
                        panelWidth: shelfPanelWidth(for: renderedRowCapacity),
                        reduceMotion: reduceMotion,
                        clearShelf: clearShelf,
                        showPreferences: showPreferences
                    )
                    .environmentObject(windowModel)
                    .frame(width: expandedContentSize.width,
                           height: expandedContentSize.height,
                           alignment: .top)
                    .zIndex(1)

                }
                .frame(width: currentShapeSize.width, height: currentShapeSize.height)
                .clipShape(
                    NotchShelfShape(
                        topCornerRadius: currentTopCornerRadius,
                        bottomCornerRadius: windowModel.expansion == .expanded
                            ? ShelfMetrics.bottomCornerRadius : 8
                    )
                )
                .animation(shelfAnimation, value: animationSignature)
                .onHover(perform: handleHover)
                .zIndex(1)
                Spacer(minLength: 0)
            }

            if windowModel.expansion == .collapsed && hasItems {
                CollapsedShelfStatusView(
                    fileCount: store.totalFileCount,
                    shelfWidth: collapsedShapeWidth,
                    notchHeight: geometry.notchHeight
                )
                .transition(.opacity)
                .zIndex(10)
                .allowsHitTesting(false)
            }
        }
        .frame(width: ShelfMetrics.windowSize.width,
               height: ShelfMetrics.windowSize.height,
               alignment: .top)
        .background(Color.clear.allowsHitTesting(false))
        .onAppear {
            windowModel.shapeSize = currentShapeSize
            playStartupGlow()
        }
        .onChange(of: currentShapeSize) { _, newSize in
            windowModel.shapeSize = newSize
        }
        .onChange(of: windowModel.glowPulse) { _, _ in
            playGlow()
        }
    }

    private func handleHover(_ hovering: Bool) {
        if hovering {
            windowModel.expand()
        } else if windowModel.expansion == .expanded {
            let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
            windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
        }
    }

    private func playStartupGlow() {
        guard !didPlayStartupGlow else { return }
        didPlayStartupGlow = true
        playGlow()
    }

    private func playGlow() {
        glowTask?.cancel()

        if reduceMotion {
            isStartupGlowVisible = true
            glowTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                isStartupGlowVisible = false
            }
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isStartupGlowVisible = true
        }

        glowTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.55)) {
                isStartupGlowVisible = false
            }
        }
    }

    private func clearShelf() {
        store.clearAll()
    }

    private func showPreferences() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}

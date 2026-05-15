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
    @State private var isStartupGlowVisible = false
    @State private var didPlayStartupGlow = false

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var hasItems: Bool { !store.items.isEmpty }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            let baseWidth = geometry.notchWidth
            let width = hasItems ? baseWidth + ShelfMetrics.collapsedExtraWidth : baseWidth
            return CGSize(width: width, height: geometry.notchHeight)
        case .expanded:
            return expandedShapeSize
        }
    }

    private var expandedShapeSize: CGSize {
        let baseRow = Swift.max(UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount), 3)
        let slotCount = store.visibleSlotCount
        let rows = Swift.max(Int((Double(slotCount) / Double(baseRow)).rounded(.up)), 1)
        let rowHeight = ShelfMetrics.itemHeight + ShelfMetrics.itemSpacing
        let chromeHeight = geometry.notchHeight
            + ShelfMetrics.shelfTopChromeHeight
            + ShelfMetrics.shelfPanelBottomPadding
        let height = chromeHeight + CGFloat(rows) * rowHeight

        let emptyWidth = geometry.notchWidth + ShelfMetrics.sideExpansion * 2
        let outerHorizontalPadding = (ShelfMetrics.topCornerRadiusExpanded + 12) * 2
        let rowWidth = CGFloat(baseRow) * ShelfMetrics.itemWidth
            + CGFloat(baseRow - 1) * ShelfMetrics.itemSpacing
            + ShelfMetrics.contentPadding * 2
            + outerHorizontalPadding
        return CGSize(
            width: Swift.min(ShelfMetrics.expandedSize.width, Swift.max(emptyWidth, rowWidth)),
            height: Swift.min(ShelfMetrics.expandedSize.height, height)
        )
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
                        topCornerRadius: currentTopCornerRadius,
                        notchHeight: geometry.notchHeight,
                        preferencesButtonTopPadding: preferencesButtonTopPadding,
                        hiddenOffset: geometry.notchHeight + ShelfMetrics.shelfTopChromeHeight,
                        contentHeight: expandedContentSize.height,
                        reduceMotion: reduceMotion,
                        clearShelf: clearShelf,
                        showPreferences: showPreferences
                    )
                    .environmentObject(windowModel)
                    .frame(width: expandedContentSize.width,
                           height: expandedContentSize.height,
                           alignment: .top)
                    .zIndex(1)

                    if windowModel.expansion == .collapsed && hasItems {
                        collapsedIndicators
                            .transition(.opacity)
                            .zIndex(2)
                    }
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

        if reduceMotion {
            isStartupGlowVisible = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                isStartupGlowVisible = false
            }
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isStartupGlowVisible = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.55)) {
                isStartupGlowVisible = false
            }
        }
    }

    // MARK: - Collapsed Indicators

    private var collapsedIndicators: some View {
        HStack(spacing: 0) {
            // Tray icon on the left — outside physical notch
            Image(systemName: "tray.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 22)
                .accessibilityLabel("NotchShelf")
                .accessibilityHidden(false)

            Spacer(minLength: 0)

            // Item count badge on the right — outside physical notch
            HStack(spacing: 3) {
                Text("\(store.totalFileCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Image(systemName: "doc.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(store.totalFileCount) files on shelf")
        }
        .padding(.horizontal, ShelfMetrics.collapsedIndicatorPadding + ShelfMetrics.topCornerRadius)
        .frame(height: geometry.notchHeight, alignment: .center)
    }

    private func clearShelf() {
        store.clearAll()
    }

    private func showPreferences() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}

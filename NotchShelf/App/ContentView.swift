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
    @AppStorage(UserDefaultsKey.playSoundOnSystemEventGlow) private var playSoundOnSystemEventGlow = false
    @State private var isStartupGlowVisible = false
    @State private var didPlayStartupGlow = false
    @State private var startupGlowFinishedAt: Date?
    @State private var glowTask: Task<Void, Never>?
    @State private var pendingGlowReplayTask: Task<Void, Never>?
    @State private var glowRGBA: RGBAColor = ContentView.loadGlowColor()

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var hasItems: Bool { !store.items.isEmpty }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: collapsedShapeWidth, height: collapsedShapeHeight)
        case .expanded:
            return expandedShapeSize
        }
    }

    private var contentSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: collapsedShapeWidth, height: collapsedShapeHeight)
        case .expanded:
            return expandedContentSize
        }
    }

    private var collapsedShapeWidth: CGFloat {
        geometry.notchWidth + geometry.notchHeight * 2
    }

    private var collapsedShapeHeight: CGFloat {
        geometry.notchHeight + ShelfMetrics.collapsedHeightExtension
    }

    private var expandedShapeSize: CGSize {
        let rowCapacity = renderedRowCapacity
        let rowCount = renderedRowCount
        let height = ShelfMetrics.shelfTopChromeHeight
            + ShelfMetrics.slotGridOutlineTop
            + ShelfMetrics.slotGridOutlineHeight(rowCount: rowCount)
            + ShelfMetrics.slotGridOutlineBottom

        let rowWidth = shelfPanelWidth(for: rowCapacity)
            + ShelfMetrics.shelfOuterHorizontalPadding * 2
        return CGSize(
            width: Swift.min(ShelfMetrics.expandedSize.width, Swift.max(geometry.notchWidth, rowWidth)),
            height: Swift.min(ShelfMetrics.expandedSize.height, height)
        )
    }

    private var expandedContentSize: CGSize {
        let rowCapacity = renderedRowCapacity
        let rowCount = renderedRowCount
        let rowHeight = CGFloat(rowCount) * ShelfMetrics.itemHeight
            + CGFloat(Swift.max(rowCount - 1, 0)) * ShelfMetrics.itemSpacing
        let height = ShelfMetrics.shelfTopChromeHeight
            + ShelfMetrics.contentPadding * 2
            + rowHeight
            + ShelfMetrics.shelfPanelBottomPadding

        let rowWidth = shelfPanelWidth(for: rowCapacity)
            + ShelfMetrics.shelfOuterHorizontalPadding * 2
        return CGSize(
            width: Swift.min(ShelfMetrics.expandedSize.width, Swift.max(geometry.notchWidth, rowWidth)),
            height: Swift.min(ShelfMetrics.windowSize.height, height)
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
            return ShelfAnimations.shelfReduced
        }
        return ShelfAnimations.shelf
    }

    var body: some View {
        let currentShapeSize = shapeSize
        let currentContentSize = contentSize
        let revealContentSize = expandedContentSize
        ZStack(alignment: .top) {
            StartupGlowView(
                topCornerRadius: currentTopCornerRadius,
                bottomCornerRadius: windowModel.expansion == .expanded
                    ? ShelfMetrics.bottomCornerRadius : 8,
                glowColor: glowRGBA.color
            )
                .frame(width: currentShapeSize.width, height: currentShapeSize.height)
                .opacity(isStartupGlowVisible ? 1 : 0)
                .allowsHitTesting(false)
                .zIndex(20)

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
                    .frame(width: currentShapeSize.width, height: currentShapeSize.height)

                    ShelfRevealContent(
                        preferencesButtonTopPadding: preferencesButtonTopPadding,
                        hiddenOffset: ShelfMetrics.shelfTopChromeHeight,
                        contentHeight: revealContentSize.height,
                        panelWidth: shelfPanelWidth(for: renderedRowCapacity),
                        reduceMotion: reduceMotion,
                        clearShelf: clearShelf,
                        showPreferences: showPreferences
                    )
                    .environmentObject(windowModel)
                    .frame(width: revealContentSize.width,
                           height: revealContentSize.height,
                           alignment: .top)
                    .zIndex(1)

                }
                .frame(width: currentShapeSize.width, height: currentContentSize.height, alignment: .top)
                .animation(shelfAnimation, value: windowModel.expansion)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    handleHover(phase, surfaceSize: currentShapeSize)
                }
                .zIndex(1)
                Spacer(minLength: 0)
            }

            if windowModel.expansion == .collapsed && hasItems {
                CollapsedShelfStatusView(
                    fileCount: store.totalFileCount,
                    shelfWidth: collapsedShapeWidth,
                    shelfHeight: collapsedShapeHeight
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
            let shouldPlaySound = windowModel.consumePendingGlowSound()
            switch StartupGlowLockoutPolicy.decision(
                now: Date(),
                startupGlowFinishedAt: startupGlowFinishedAt
            ) {
            case .playNow:
                pendingGlowReplayTask?.cancel()
                pendingGlowReplayTask = nil
                playGlow(playSound: shouldPlaySound)
            case .replayAfter(let delay):
                schedulePendingGlowReplay(after: delay, playSound: shouldPlaySound)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let next = Self.loadGlowColor()
            if next != glowRGBA { glowRGBA = next }
        }
    }

    private func handleHover(_ phase: HoverPhase, surfaceSize: CGSize) {
        switch phase {
        case .active(let location):
            guard windowModel.expansion == .expanded || collapsedHoverRect(in: surfaceSize).contains(location) else {
                return
            }
            windowModel.expand()
        case .ended:
            guard windowModel.expansion == .expanded else { return }
            windowModel.scheduleCollapse(after: AutoHidePolicy.collapseDelay())
        }
    }

    private func collapsedHoverRect(in surfaceSize: CGSize) -> CGRect {
        let width = Swift.min(
            surfaceSize.width,
            geometry.notchWidth + ShelfMetrics.collapsedHoverHorizontalOutset * 2
        )
        let height = Swift.min(
            surfaceSize.height,
            geometry.notchHeight + ShelfMetrics.collapsedHoverLowerOutset
        )
        return CGRect(
            x: (surfaceSize.width - width) / 2,
            y: 0,
            width: width,
            height: height
        )
    }

    private func playStartupGlow() {
        guard !didPlayStartupGlow else { return }
        didPlayStartupGlow = true
        // Lock out system-event pulses until the startup glow's full envelope ends.
        let envelopeMillis: Double = reduceMotion ? 700 : 1_200
        startupGlowFinishedAt = Date().addingTimeInterval(envelopeMillis / 1_000)
        playGlow(playSound: false)
    }

    private func playGlow(playSound: Bool) {
        glowTask?.cancel()
        if playSound && playSoundOnSystemEventGlow {
            SystemGlowSoundPlayer.play()
        }

        if reduceMotion {
            isStartupGlowVisible = true
            glowTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(ShelfAnimations.Glow.reducedMotionHoldMillis))
                guard !Task.isCancelled else { return }
                isStartupGlowVisible = false
            }
            return
        }

        // Snap any in-flight fade-out to zero before starting a new pulse so
        // overlapping animation transactions cannot leave opacity stuck at an
        // intermediate value.
        var snapTransaction = Transaction(animation: nil)
        snapTransaction.disablesAnimations = true
        withTransaction(snapTransaction) {
            isStartupGlowVisible = false
        }

        withAnimation(.easeOut(duration: ShelfAnimations.Glow.inDuration)) {
            isStartupGlowVisible = true
        }

        glowTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ShelfAnimations.Glow.holdMillis))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: ShelfAnimations.Glow.outDuration)) {
                isStartupGlowVisible = false
            }
        }
    }

    private func schedulePendingGlowReplay(after seconds: TimeInterval, playSound: Bool) {
        pendingGlowReplayTask?.cancel()
        let milliseconds = Int((seconds * 1_000).rounded(.up))
        pendingGlowReplayTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else { return }
            pendingGlowReplayTask = nil
            playGlow(playSound: playSound)
        }
    }

    private static func loadGlowColor() -> RGBAColor {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.glowColor) as? [Double]
            ?? RGBAColor.defaultGlow.components
        return RGBAColor(components: components, fallback: .defaultGlow)
    }

    private func clearShelf() {
        store.clearAll()
    }

    private func showPreferences() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}

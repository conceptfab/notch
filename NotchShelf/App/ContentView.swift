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
        let chromeHeight = geometry.notchHeight + 24 + ShelfMetrics.shelfPanelBottomPadding
        let height = chromeHeight + CGFloat(rows) * rowHeight

        let emptyWidth = geometry.notchWidth + ShelfMetrics.sideExpansion * 2
        let rowWidth = CGFloat(baseRow) * ShelfMetrics.itemWidth
            + CGFloat(baseRow - 1) * ShelfMetrics.itemSpacing
            + ShelfMetrics.contentPadding * 2
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

    private var shelfContentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.97, anchor: .top)),
            removal: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .top))
        )
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
        VStack(spacing: 0) {
            ZStack {
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

                if windowModel.expansion == .expanded {
                    ShelfView()
                        .environmentObject(windowModel)
                        .padding(.horizontal, currentTopCornerRadius + 12)
                        .padding(.top, geometry.notchHeight + 12)
                        .padding(.bottom, ShelfMetrics.shelfPanelBottomPadding)
                        .transition(shelfContentTransition)
                        .zIndex(1)

                    topBar
                        .padding(.top, preferencesButtonTopPadding)
                        .transition(shelfContentTransition)
                        .zIndex(2)
                } else if hasItems {
                    collapsedIndicators
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(width: shapeSize.width, height: shapeSize.height)
            .clipped()
            .animation(shelfAnimation, value: animationSignature)
            .onHover(perform: handleHover)
            Spacer(minLength: 0)
        }
        .frame(width: ShelfMetrics.windowSize.width,
               height: ShelfMetrics.windowSize.height,
               alignment: .top)
        .background(Color.clear.allowsHitTesting(false))
    }

    private func handleHover(_ hovering: Bool) {
        if hovering {
            windowModel.expand()
        } else if windowModel.expansion == .expanded {
            let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
            windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
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
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
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
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(store.totalFileCount) files on shelf")
        }
        .padding(.horizontal, ShelfMetrics.collapsedIndicatorPadding + ShelfMetrics.topCornerRadius)
    }

    // MARK: - Preferences

    private var topBar: some View {
        VStack {
            HStack {
                ShelfClearButton(action: clearShelf)
                    .padding(.leading, currentTopCornerRadius + 8)
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
                    .padding(.trailing, currentTopCornerRadius + 8)
            }
            Spacer()
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

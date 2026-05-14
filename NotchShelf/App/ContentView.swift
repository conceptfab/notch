import SwiftUI
import AppKit

/// Root view hosted inside the notch panel. Draws the continuous notch-into-shelf
/// shape sized from `ShelfWindowModel.expansion`, with shelf content layered inside
/// the shape when expanded.
struct ContentView: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel
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
        let emptyWidth = geometry.notchWidth + ShelfMetrics.sideExpansion * 2
        let itemCount = CGFloat(store.items.count)
        let itemWidth = itemCount * ShelfMetrics.itemWidth
        let spacingWidth = max(0, itemCount - 1) * ShelfMetrics.itemSpacing
        let contentWidth = itemWidth + spacingWidth + ShelfMetrics.contentPadding * 2
        return CGSize(
            width: min(ShelfMetrics.expandedSize.width, max(emptyWidth, contentWidth)),
            height: ShelfMetrics.expandedSize.height
        )
    }

    private var currentTopCornerRadius: CGFloat {
        windowModel.expansion == .expanded
            ? ShelfMetrics.topCornerRadiusExpanded
            : ShelfMetrics.topCornerRadius
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
                        .transition(.opacity)

                    // Gear icon — absolute top-right corner of the application shape
                    shelfMenu
                        .padding(.top, 8)
                        .padding(.trailing, currentTopCornerRadius + 8)
                        .transition(.opacity)
                } else if hasItems {
                    collapsedIndicators
                        .transition(.opacity)
                }
            }
            .frame(width: shapeSize.width, height: shapeSize.height)
            .onHover { hovering in
                if hovering {
                    windowModel.expand()
                } else if windowModel.expansion == .expanded {
                    windowModel.scheduleCollapse()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: ShelfMetrics.windowSize.width,
               height: ShelfMetrics.windowSize.height,
               alignment: .top)
        .background(Color.clear.allowsHitTesting(false))
        .animation(windowModel.animation, value: windowModel.expansion)
        .onAppear { ShelfStore.shared.cleanupInvalidItems() }
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

            Spacer(minLength: 0)

            // Item count badge on the right — outside physical notch
            HStack(spacing: 3) {
                Text("\(store.items.count)")
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
        }
        .padding(.horizontal, ShelfMetrics.collapsedIndicatorPadding + ShelfMetrics.topCornerRadius)
    }

    // MARK: - Shelf Menu

    private var shelfMenu: some View {
        VStack {
            HStack {
                Spacer()
                Menu {
                    Button("Preferencje") {
                        openSettings()
                    }
                    Divider()
                    Button("Zamknij aplikację") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

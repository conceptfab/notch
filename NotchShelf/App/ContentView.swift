import SwiftUI

/// Root view hosted inside the notch panel. Draws the continuous notch-into-shelf
/// shape sized from `ShelfWindowModel.expansion`, with shelf content layered inside
/// the shape when expanded.
struct ContentView: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .expanded:
            return ShelfMetrics.expandedSize
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NotchShelfShape(
                    topCornerRadius: ShelfMetrics.topCornerRadius,
                    bottomCornerRadius: windowModel.expansion == .expanded
                        ? ShelfMetrics.bottomCornerRadius : 8
                )
                .fill(Color.black)

                if windowModel.expansion == .expanded {
                    ShelfView()
                        .environmentObject(windowModel)
                        .padding(.horizontal, 16)
                        .padding(.top, geometry.notchHeight)
                        .padding(.bottom, 14)
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
}

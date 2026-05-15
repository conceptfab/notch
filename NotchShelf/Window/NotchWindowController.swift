import AppKit
import SwiftUI

/// Owns the notch panel: builds it, hosts `ContentView`, and keeps it positioned at
/// the top-center of the notch screen as screen layout changes.
@MainActor
final class NotchWindowController: NSObject {
    private let panel: NotchPanel
    private let windowModel: ShelfWindowModel

    init(windowModel: ShelfWindowModel) {
        self.windowModel = windowModel
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: ShelfMetrics.windowSize)
        )
        super.init()

        let root = ContentView().environmentObject(windowModel)
        panel.contentView = NSHostingView(rootView: root)
        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// The panel's current frame in global screen coordinates.
    var panelFrame: CGRect {
        panel.frame
    }

    /// Centers the panel horizontally on the notch screen with its top flush to the
    /// screen's top edge.
    func reposition() {
        guard let screen = NotchGeometry.notchScreen else { return }
        let geometry = NotchGeometry.current()
        let frame = screen.frame
        let size = ShelfMetrics.windowSize
        let origin = NSPoint(
            x: geometry.notchRect.midX - size.width / 2,
            y: frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    @objc private func screenParametersChanged() {
        reposition()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

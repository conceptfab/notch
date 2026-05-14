import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var dragMonitor: DragMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        menuBarController = MenuBarController()
        setupDragMonitor()
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func setupDragMonitor() {
        let monitor = DragMonitor(regionProvider: { [weak self] in
            guard let self else { return .zero }
            switch self.windowModel.expansion {
            case .collapsed:
                return NotchGeometry.current().notchRect
            case .expanded:
                return self.windowController?.panelFrame ?? NotchGeometry.current().notchRect
            }
        })
        monitor.onEnterRegion = { [weak self] in
            self?.windowModel.expand()
            self?.windowModel.dragTargeting = true
        }
        monitor.onExitRegion = { [weak self] in
            self?.windowModel.dragTargeting = false
        }
        monitor.onDragEnd = { [weak self] in
            guard let self else { return }
            if self.windowModel.dropEvent {
                self.windowModel.dropEvent = false
            } else if !self.windowModel.dragTargeting {
                self.windowModel.scheduleCollapse()
            }
        }
        monitor.startMonitoring()
        dragMonitor = monitor
    }
}

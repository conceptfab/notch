import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var dragMonitor: DragMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerPreferenceDefaults()
        guard !Self.isRunningTests else { return }
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        setupDragMonitor()
        ShelfStore.shared.cleanupInvalidItems()
        reconcileLaunchAtLoginPreference()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stopMonitoring()
        dragMonitor = nil
        ShelfStore.shared.flushPendingSaveSync()
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func setupDragMonitor() {
        let monitor = DragMonitor(regionProvider: { [weak self] in
            guard let self else { return .zero }
            guard !ShelfSelection.shared.isDragging else { return .zero }
            switch self.windowModel.expansion {
            case .collapsed:
                return NotchGeometry.current().dragCatchRegion()
            case .expanded:
                return (self.windowController?.panelFrame ?? NotchGeometry.current().notchRect)
                    .insetBy(
                        dx: -ShelfMetrics.dragExitHorizontalOutset,
                        dy: -ShelfMetrics.dragExitVerticalOutset
                    )
            }
        })
        monitor.onEnterRegion = { [weak self] in
            self?.windowModel.expand()
            self?.windowModel.setDragTargeting(true)
        }
        monitor.onExitRegion = { [weak self] in
            self?.windowModel.setDragTargeting(false)
        }
        monitor.onDragEnd = { [weak self] in
            guard let self else { return }
            if self.windowModel.dropEvent {
                self.windowModel.dropEvent = false
            } else if !self.windowModel.dragTargeting {
                let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
                self.windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
            }
        }
        monitor.startMonitoring()
        dragMonitor = monitor
    }

    private func reconcileLaunchAtLoginPreference() {
        let storedPref = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin)
        let actual = LaunchAtLoginService.shared.isCurrentlyEnabled
        if storedPref != actual {
            UserDefaults.standard.set(actual, forKey: UserDefaultsKey.launchAtLogin)
        }
    }
}

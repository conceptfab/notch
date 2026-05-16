import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var dragMonitor: DragMonitor?
    private var workspaceEventObservers: [NSObjectProtocol] = []
    private var appEventObservers: [NSObjectProtocol] = []
    private var distributedEventObservers: [NSObjectProtocol] = []
    private var systemNotificationWindowMonitor: SystemNotificationWindowMonitor?
    private var lastSystemGlowDate = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerPreferenceDefaults()
        guard !Self.isRunningTests else { return }
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        setupDragMonitor()
        setupSystemEventGlowObservers()
        ShelfStore.shared.cleanupInvalidItems()
        reconcileLaunchAtLoginPreference()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tearDownSystemEventGlowObservers()
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

    private func setupSystemEventGlowObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceEventObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerSystemEventGlowIfEnabled(reason: "wake")
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerSystemEventGlowIfEnabled(reason: "session-active")
                }
            }
        ]

        appEventObservers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerSystemEventGlowIfEnabled(reason: "screen-parameters")
                }
            }
        ]

        let distributedCenter = DistributedNotificationCenter.default()
        distributedEventObservers = [
            "com.apple.notificationcenterui.banner",
            "com.apple.notificationcenterui.customalerts",
            "com.apple.notificationcenterui.customalerts-alive"
        ].map { name in
            distributedCenter.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerSystemEventGlowIfEnabled(reason: name)
                }
            }
        }
        distributedEventObservers.append(
            distributedCenter.addObserver(
                forName: nil,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let notificationName = notification.name.rawValue
                Task { @MainActor [weak self] in
                    guard let name = notificationName.nonEmpty,
                          Self.isLikelyNotificationDistributedEvent(name)
                    else { return }
                    self?.triggerSystemEventGlowIfEnabled(reason: name)
                }
            }
        )

        let monitor = SystemNotificationWindowMonitor { [weak self] in
            self?.triggerSystemEventGlowIfEnabled(reason: "notification-window")
        }
        monitor.start()
        systemNotificationWindowMonitor = monitor
    }

    static func isLikelyNotificationDistributedEvent(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.contains("notificationcenter")
            || lowercasedName.contains("usernotification")
            || lowercasedName.contains("customalerts")
            || lowercasedName.contains("banner")
    }

    private func tearDownSystemEventGlowObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceEventObservers {
            workspaceCenter.removeObserver(observer)
        }
        workspaceEventObservers.removeAll()

        for observer in appEventObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appEventObservers.removeAll()

        let distributedCenter = DistributedNotificationCenter.default()
        for observer in distributedEventObservers {
            distributedCenter.removeObserver(observer)
        }
        distributedEventObservers.removeAll()

        systemNotificationWindowMonitor?.stop()
        systemNotificationWindowMonitor = nil
    }

    private func triggerSystemEventGlowIfEnabled(reason: String) {
        guard UserDefaults.standard.bool(forKey: UserDefaultsKey.glowOnSystemEvents) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSystemGlowDate) >= 0.8 else { return }
        lastSystemGlowDate = now
        AppLogger.systemEvents.notice("System glow requested: \(reason, privacy: .public)")
        windowModel.requestGlow()
    }

    private func reconcileLaunchAtLoginPreference() {
        let storedPref = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin)
        let actual = LaunchAtLoginService.shared.isCurrentlyEnabled
        if storedPref != actual {
            UserDefaults.standard.set(actual, forKey: UserDefaultsKey.launchAtLogin)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

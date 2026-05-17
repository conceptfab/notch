import AppKit

/// Owns subscription to system events that should pulse the notch glow:
/// workspace wake/session events, screen-parameter changes, distributed
/// notifications from Notification Center, and a polling window monitor that
/// catches banners without a public notification.
///
/// Extracted from `AppDelegate` to keep that type focused on app lifecycle.
@MainActor
final class SystemEventGlowCoordinator {
    private let defaults: UserDefaults
    private let onGlow: @MainActor (String) -> Void
    private var workspaceEventObservers: [NSObjectProtocol] = []
    private var appEventObservers: [NSObjectProtocol] = []
    private var distributedEventObservers: [NSObjectProtocol] = []
    private var systemNotificationWindowMonitor: SystemNotificationWindowMonitor?
    private var lastGlowDate = Date.distantPast
    private let rateLimit: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        rateLimit: TimeInterval = 0.8,
        onGlow: @escaping @MainActor (String) -> Void
    ) {
        self.defaults = defaults
        self.rateLimit = rateLimit
        self.onGlow = onGlow
    }

    func start() {
        stop()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceEventObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: "wake")
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: "session-active")
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
                    self?.triggerGlowIfEnabled(reason: "screen-parameters")
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
                    self?.triggerGlowIfEnabled(reason: name)
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
                    guard !notificationName.isEmpty,
                          Self.isLikelyNotificationDistributedEvent(notificationName)
                    else { return }
                    self?.triggerGlowIfEnabled(reason: notificationName)
                }
            }
        )

        let monitor = SystemNotificationWindowMonitor { [weak self] in
            self?.triggerGlowIfEnabled(reason: "notification-window")
        }
        monitor.start()
        systemNotificationWindowMonitor = monitor
    }

    func stop() {
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

    static func isLikelyNotificationDistributedEvent(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.contains("notificationcenter")
            || lowercasedName.contains("usernotification")
            || lowercasedName.contains("customalerts")
            || lowercasedName.contains("banner")
    }

    func triggerGlowIfEnabled(reason: String) {
        guard defaults.bool(forKey: UserDefaultsKey.glowOnSystemEvents) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastGlowDate) >= rateLimit else { return }
        lastGlowDate = now
        AppLogger.systemEvents.notice("System glow requested: \(reason, privacy: .public)")
        onGlow(reason)
    }
}

import AppKit
import CoreGraphics

/// Detects visible macOS notification banners when Notification Center does not
/// publish a public app-level notification for the event.
@MainActor
final class SystemNotificationWindowMonitor {
    private static let notificationBundleIdentifiers: Set<String> = [
        "com.apple.notificationcenter",
        "com.apple.notificationcenterui",
        "com.apple.UserNotificationCenter"
    ]

    private let interval: TimeInterval
    private let onNotificationShown: @MainActor () -> Void
    private var timer: Timer?
    private var visibleWindowIDs = Set<CGWindowID>()

    init(interval: TimeInterval = 0.35, onNotificationShown: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.onNotificationShown = onNotificationShown
    }

    func start() {
        stop()
        visibleWindowIDs = currentNotificationWindowIDs()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        visibleWindowIDs.removeAll()
    }

    private func poll() {
        let currentIDs = currentNotificationWindowIDs()
        let newIDs = currentIDs.subtracting(visibleWindowIDs)
        visibleWindowIDs = currentIDs

        guard !newIDs.isEmpty else { return }
        onNotificationShown()
    }

    private func currentNotificationWindowIDs() -> Set<CGWindowID> {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return Set(windows.compactMap { windowInfo in
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  Self.isNotificationWindow(windowInfo)
            else {
                return nil
            }
            return windowID
        })
    }

    static func isNotificationWindow(_ windowInfo: [String: Any]) -> Bool {
        guard let pidNumber = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
              let app = NSRunningApplication(processIdentifier: pidNumber.int32Value),
              let bundleIdentifier = app.bundleIdentifier,
              let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
        else {
            return false
        }

        let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        let alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
        return isLikelyNotificationWindow(
            bundleIdentifier: bundleIdentifier,
            bounds: bounds,
            layer: layer,
            alpha: alpha
        )
    }

    static func isLikelyNotificationWindow(
        bundleIdentifier: String,
        bounds: [String: Any],
        layer: Int,
        alpha: Double
    ) -> Bool {
        guard notificationBundleIdentifiers.contains(bundleIdentifier),
              alpha > 0.05,
              layer >= 0
        else {
            return false
        }

        let width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
        let height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
        return width >= 180 && height >= 40
    }
}

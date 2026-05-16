import Foundation
import Testing
@testable import NotchShelf

@MainActor @Test func notificationWindowMonitorAcceptsNotificationCenterBannerSizedWindows() {
    let bounds: [String: Any] = [
        "Width": NSNumber(value: 360),
        "Height": NSNumber(value: 88)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.apple.notificationcenterui",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ))
}

@MainActor @Test func notificationWindowMonitorRejectsTinyNotificationCenterWindows() {
    let bounds: [String: Any] = [
        "Width": NSNumber(value: 40),
        "Height": NSNumber(value: 24)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.apple.notificationcenterui",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ) == false)
}

@MainActor @Test func notificationWindowMonitorRejectsOtherApps() {
    let bounds: [String: Any] = [
        "Width": NSNumber(value: 360),
        "Height": NSNumber(value: 88)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.example.SomeApp",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ) == false)
}

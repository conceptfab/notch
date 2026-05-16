import Foundation
import Testing
@testable import NotchShelf

@MainActor @Test func notificationWindowMonitorAcceptsNotificationCenterBannerSizedWindows() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1100),
        "Y": NSNumber(value: 36),
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

@MainActor @Test func notificationWindowMonitorAcceptsOwnerNameWhenBundleIdentifierIsMissing() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1100),
        "Y": NSNumber(value: 36),
        "Width": NSNumber(value: 408),
        "Height": NSNumber(value: 112)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: nil,
        ownerName: "Notification Center",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ))
}

@MainActor @Test func notificationWindowMonitorAcceptsUserNotificationBundleVariants() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1100),
        "Y": NSNumber(value: 36),
        "Width": NSNumber(value: 408),
        "Height": NSNumber(value: 112)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.apple.usernotifications.usernotificationcenter",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ))
}

@MainActor @Test func notificationWindowMonitorRejectsTinyNotificationCenterWindows() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1100),
        "Y": NSNumber(value: 36),
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
        "X": NSNumber(value: 40),
        "Y": NSNumber(value: 700),
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

@MainActor @Test func notificationWindowMonitorAcceptsTopRightBannerGeometryEvenForMailOwner() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1120),
        "Y": NSNumber(value: 42),
        "Width": NSNumber(value: 410),
        "Height": NSNumber(value: 112)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.apple.mail",
        ownerName: "Mail",
        bounds: bounds,
        layer: 25,
        alpha: 1.0
    ))
}

@MainActor @Test func notificationWindowMonitorRejectsNormalTopRightAppWindowLayer() {
    let bounds: [String: Any] = [
        "X": NSNumber(value: 1120),
        "Y": NSNumber(value: 42),
        "Width": NSNumber(value: 410),
        "Height": NSNumber(value: 112)
    ]

    #expect(SystemNotificationWindowMonitor.isLikelyNotificationWindow(
        bundleIdentifier: "com.example.SomeApp",
        ownerName: "SomeApp",
        bounds: bounds,
        layer: 0,
        alpha: 1.0
    ) == false)
}

@MainActor @Test func distributedNotificationFallbackAcceptsNotificationCenterNames() {
    #expect(AppDelegate.isLikelyNotificationDistributedEvent("com.apple.notificationcenterui.banner"))
    #expect(AppDelegate.isLikelyNotificationDistributedEvent("com.apple.UserNotificationCenter.delivered"))
}

@MainActor @Test func distributedNotificationFallbackRejectsUnrelatedNames() {
    #expect(AppDelegate.isLikelyNotificationDistributedEvent("com.apple.HIToolbox.beginMenuTracking") == false)
}

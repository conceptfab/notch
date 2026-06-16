import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("SystemEventGlowCoordinator")
struct SystemEventGlowCoordinatorTests {
    @Test
    func doesNotTrigger_whenDefaultDisabled() {
        let defaults = makeTestUserDefaults()
        defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
        var glowReasons: [String] = []
        let coordinator = SystemEventGlowCoordinator(defaults: defaults) { reason in
            glowReasons.append(reason)
        }

        coordinator.triggerGlowIfEnabled(reason: "test")

        #expect(glowReasons.isEmpty)
    }

    @Test
    func appliesRateLimit_whenTriggeredRepeatedly() {
        let defaults = makeTestUserDefaults()
        defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
        var glowReasons: [String] = []
        let coordinator = SystemEventGlowCoordinator(defaults: defaults, rateLimit: 10) { reason in
            glowReasons.append(reason)
        }

        coordinator.triggerGlowIfEnabled(reason: "first")
        coordinator.triggerGlowIfEnabled(reason: "second")

        #expect(glowReasons == ["first"])
    }

    @Test
    func startedCoordinatorTriggersForDistributedNotification() async throws {
        let defaults = makeTestUserDefaults()
        defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
        let notificationName = "com.apple.notificationcenterui.banner"
        var glowReasons: [String] = []
        let coordinator = SystemEventGlowCoordinator(defaults: defaults, rateLimit: 0) { reason in
            glowReasons.append(reason)
        }
        coordinator.start()
        defer { coordinator.stop() }

        DistributedNotificationCenter.default().post(
            name: Notification.Name(notificationName),
            object: nil
        )

        for _ in 0..<10 where !glowReasons.contains(notificationName) {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(glowReasons.contains(notificationName))
    }

    @MainActor @Test func glowCoordinatorDoesNotMonitorWindowsWhenSystemEventGlowDisabled() {
        let defaults = makeTestUserDefaults()
        defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
        let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
        coordinator.start()
        #expect(coordinator.isMonitoringNotificationWindows == false)
        coordinator.stop()
    }

    @MainActor @Test func glowCoordinatorMonitorsWindowsWhenSystemEventGlowEnabled() {
        let defaults = makeTestUserDefaults()
        defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
        let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
        coordinator.start()
        #expect(coordinator.isMonitoringNotificationWindows == true)
        coordinator.stop()
    }

    @MainActor @Test func glowCoordinatorStopsMonitoringWhenPreferenceTurnedOff() {
        let defaults = makeTestUserDefaults()
        defaults.set(true, forKey: UserDefaultsKey.glowOnSystemEvents)
        let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in }
        coordinator.start()
        #expect(coordinator.isMonitoringNotificationWindows == true)

        defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
        coordinator.refreshWindowMonitor()
        #expect(coordinator.isMonitoringNotificationWindows == false)
        coordinator.stop()
    }

}

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
    func acceptsNotificationCenterDistributedNames() {
        #expect(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.notificationcenterui.banner"))
        #expect(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.usernotificationcenter.foo"))
        #expect(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("BannerArrival"))
    }

    @Test
    func rejectsUnrelatedDistributedNames() {
        #expect(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.dock.changed") == false)
        #expect(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("") == false)
    }
}

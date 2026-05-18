import Foundation
import Testing
@testable import NotchShelf

@Suite("StartupGlowLockoutPolicy")
struct StartupGlowLockoutPolicyTests {
    @Test
    func playsImmediatelyWhenStartupGlowHasFinished() {
        let now = Date()
        let decision = StartupGlowLockoutPolicy.decision(
            now: now,
            startupGlowFinishedAt: now.addingTimeInterval(-0.1)
        )

        #expect(decision == .playNow)
    }

    @Test
    func replaysAfterStartupGlowWhenEventArrivesDuringLockout() {
        let now = Date()
        let decision = StartupGlowLockoutPolicy.decision(
            now: now,
            startupGlowFinishedAt: now.addingTimeInterval(0.5)
        )

        #expect(decision == .replayAfter(0.5))
    }
}

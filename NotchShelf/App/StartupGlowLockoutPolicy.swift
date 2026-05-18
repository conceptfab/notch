import Foundation

enum StartupGlowLockoutPolicy {
    enum Decision: Equatable {
        case playNow
        case replayAfter(TimeInterval)
    }

    static func decision(now: Date, startupGlowFinishedAt: Date?) -> Decision {
        guard let startupGlowFinishedAt else { return .playNow }
        let remaining = startupGlowFinishedAt.timeIntervalSince(now)
        guard remaining > 0 else { return .playNow }
        return .replayAfter(remaining)
    }
}

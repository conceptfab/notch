import Foundation

/// Pure policy resolving the auto-hide delay from defaults. Centralizes the
/// fallback applied across `ContentView` and `AppDelegate`.
enum AutoHidePolicy {
    static let fallbackDelaySeconds: TimeInterval = 1.5

    static func collapseDelay(defaults: UserDefaults = .standard) -> TimeInterval {
        let stored = defaults.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
        return stored > 0 ? stored : fallbackDelaySeconds
    }
}

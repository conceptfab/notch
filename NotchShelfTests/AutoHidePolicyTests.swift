import Testing
@testable import NotchShelf

@Suite("AutoHidePolicy")
struct AutoHidePolicyTests {
    @Test
    func test_returnsStoredDelay_whenPositive() {
        let defaults = makeTestUserDefaults()
        defaults.set(2.5, forKey: UserDefaultsKey.autoHideDelaySeconds)
        #expect(AutoHidePolicy.collapseDelay(defaults: defaults) == 2.5)
    }

    @Test
    func test_returnsFallback_whenStoredValueIsZero() {
        let defaults = makeTestUserDefaults()
        defaults.set(0, forKey: UserDefaultsKey.autoHideDelaySeconds)
        #expect(AutoHidePolicy.collapseDelay(defaults: defaults) == AutoHidePolicy.fallbackDelaySeconds)
    }

    @Test
    func test_returnsFallback_whenKeyIsMissing() {
        let defaults = makeTestUserDefaults()
        defaults.removeObject(forKey: UserDefaultsKey.autoHideDelaySeconds)
        #expect(AutoHidePolicy.collapseDelay(defaults: defaults) == AutoHidePolicy.fallbackDelaySeconds)
    }

    @Test
    func test_returnsFallback_whenStoredValueIsNegative() {
        let defaults = makeTestUserDefaults()
        defaults.set(-1.0, forKey: UserDefaultsKey.autoHideDelaySeconds)
        #expect(AutoHidePolicy.collapseDelay(defaults: defaults) == AutoHidePolicy.fallbackDelaySeconds)
    }
}

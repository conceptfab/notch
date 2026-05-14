import Testing
import Foundation
@testable import NotchShelf

@Test func preferencesDefaultToFalse() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = Preferences(defaults: suite)
    #expect(prefs.copyOnDrag == false)
}

@Test func preferencesPersistWrites() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = Preferences(defaults: suite)
    prefs.copyOnDrag = true
    #expect(prefs.copyOnDrag == true)
}

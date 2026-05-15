import Foundation
import Testing
@testable import NotchShelf

@Suite("PreferencesKeys")
struct PreferencesKeysTests {
    @Test
    func registerPreferenceDefaultsInstallsExpectedValues() {
        let suiteName = "PreferencesKeysTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        registerPreferenceDefaults(in: suite)

        #expect(suite.bool(forKey: UserDefaultsKey.copyOnDrag) == false)
        #expect(suite.double(forKey: UserDefaultsKey.autoHideDelaySeconds) == 1.5)
        #expect(suite.bool(forKey: UserDefaultsKey.launchAtLogin) == false)
        #expect(suite.integer(forKey: UserDefaultsKey.minSlotCount) == 5)
        #expect(suite.integer(forKey: UserDefaultsKey.maxSlotCount) == 15)
        #expect(suite.integer(forKey: UserDefaultsKey.stackListGridThreshold) == 5)
        let storedColor = suite.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
        #expect(storedColor == [0.0, 0.88, 0.84, 1.0])
    }

    @Test
    func registerPreferenceDefaultsInstallsDropZoneColor() {
        let suiteName = "PreferencesKeysTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        registerPreferenceDefaults(in: suite)

        let stored = suite.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
        #expect(stored == RGBAColor.defaultDropZone.components)
    }

    @Test
    func dropZoneColorKeyIsStable() {
        #expect(UserDefaultsKey.dropZoneColor == "dropZoneColor")
    }

    @Test
    func keysAreStable() {
        // Keys are persisted on disk; accidental renames are silent data loss.
        #expect(UserDefaultsKey.copyOnDrag == "copyOnDrag")
        #expect(UserDefaultsKey.autoHideDelaySeconds == "autoHideDelaySeconds")
        #expect(UserDefaultsKey.launchAtLogin == "launchAtLogin")
        #expect(UserDefaultsKey.minSlotCount == "minSlotCount")
        #expect(UserDefaultsKey.maxSlotCount == "maxSlotCount")
        #expect(UserDefaultsKey.stackListGridThreshold == "stackListGridThreshold")
    }
}

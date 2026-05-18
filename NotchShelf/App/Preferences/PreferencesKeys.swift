import Foundation

/// All persisted user preference keys. Keep names string-stable across versions;
/// renaming silently loses existing user data.
enum UserDefaultsKey {
    static let copyOnDrag = "copyOnDrag"
    static let autoHideDelaySeconds = "autoHideDelaySeconds"
    static let launchAtLogin = "launchAtLogin"
    static let glowOnSystemEvents = "glowOnSystemEvents"
    static let playSoundOnSystemEventGlow = "playSoundOnSystemEventGlow"
    static let minSlotCount = "minSlotCount"
    static let maxSlotCount = "maxSlotCount"
    static let stackListGridThreshold = "stackListGridThreshold"
    static let dropZoneColor = "dropZoneColor"
    static let glowColor = "glowColor"
}

/// Installs default values for every preference. Must be called once at launch,
/// before any `@AppStorage` is read.
func registerPreferenceDefaults(in defaults: UserDefaults = .standard) {
    defaults.register(defaults: [
        UserDefaultsKey.copyOnDrag: false,
        UserDefaultsKey.autoHideDelaySeconds: 1.5,
        UserDefaultsKey.launchAtLogin: false,
        UserDefaultsKey.glowOnSystemEvents: true,
        UserDefaultsKey.playSoundOnSystemEventGlow: false,
        UserDefaultsKey.minSlotCount: ShelfMetrics.defaultSlotCount,
        UserDefaultsKey.maxSlotCount: ShelfMetrics.defaultAdditionalRowCount,
        UserDefaultsKey.stackListGridThreshold: 5,
        UserDefaultsKey.dropZoneColor: RGBAColor.defaultDropZone.components,
        UserDefaultsKey.glowColor: RGBAColor.defaultGlow.components
    ])
}

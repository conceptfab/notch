import Foundation

/// App preferences backed by `UserDefaults`. Both keys default to `false`.
final class Preferences: @unchecked Sendable {
    static let shared = Preferences()

    private let defaults: UserDefaults
    private enum Key {
        static let copyOnDrag = "copyOnDrag"
        static let autoRemoveShelfItems = "autoRemoveShelfItems"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// When true, dragging items off the shelf is restricted to copy (never move).
    var copyOnDrag: Bool {
        get { defaults.bool(forKey: Key.copyOnDrag) }
        set { defaults.set(newValue, forKey: Key.copyOnDrag) }
    }

    /// When true, a successful drag-out removes the item from the shelf.
    var autoRemoveShelfItems: Bool {
        get { defaults.bool(forKey: Key.autoRemoveShelfItems) }
        set { defaults.set(newValue, forKey: Key.autoRemoveShelfItems) }
    }
}

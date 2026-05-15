import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private let service = SMAppService.mainApp

    private init() {}

    /// Test seam: pure policy mapping of `SMAppService.Status.rawValue` to Bool.
    static func isEnabled(rawStatus: Int) -> Bool {
        rawStatus == SMAppService.Status.enabled.rawValue
    }

    var isCurrentlyEnabled: Bool {
        Self.isEnabled(rawStatus: service.status.rawValue)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            AppLogger.shelf.error("LaunchAtLoginService.setEnabled(\(enabled)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("LaunchAtLoginService")
struct LaunchAtLoginServiceTests {
    @Test
    func policyMapsStatusToBool() {
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 1) == true)
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 0) == false)
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 2) == false)
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 3) == false)
    }
}

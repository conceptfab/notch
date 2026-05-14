import Testing
import Foundation
@testable import NotchShelf

@Test func accessSecurityScopedResourceRunsAccessorAndReturnsValue() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "hello".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let contents = tmp.accessSecurityScopedResource { url in
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    #expect(contents == "hello")
}

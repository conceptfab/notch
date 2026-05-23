import AppKit
import XCTest

final class BundleResourceTests: XCTestCase {
    func testLicenseTextIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
            "LICENSE.txt must be bundled in the app's Resources"
        )

        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("MIT License"))
        XCTAssertTrue(
            contents.contains("conceptfab.com"),
            "LICENSE.txt must use the public ConceptFab brand"
        )
        XCTAssertFalse(contents.contains("Kleniewski"))
    }

    func testBuyMeACoffeeImageIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "buy-me-a-coffee", withExtension: "png"),
            "buy-me-a-coffee.png must be bundled"
        )

        let image = try XCTUnwrap(NSImage(contentsOf: url), "must be a readable PNG")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}

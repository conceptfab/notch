import XCTest

final class InfoPlistMetadataTests: XCTestCase {
    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    func testBundleIdentifierIsConceptFabNamespace() throws {
        let bundleIdentifier = try XCTUnwrap(info["CFBundleIdentifier"] as? String)
        XCTAssertEqual(bundleIdentifier, "dev.conceptfab.notchshelf")
    }

    func testCopyrightUsesConceptFabBranding() throws {
        let copyright = try XCTUnwrap(info["NSHumanReadableCopyright"] as? String)
        XCTAssertEqual(
            copyright,
            "Copyright \u{00a9} 2026 conceptfab.com. All rights reserved."
        )
        XCTAssertFalse(
            copyright.contains("Kleniewski"),
            "user-facing metadata must use the ConceptFab brand, not a personal name"
        )
    }

    func testGetInfoStringContainsVersionAndConceptFabBrand() throws {
        let getInfo = try XCTUnwrap(info["CFBundleGetInfoString"] as? String)
        let version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)
        XCTAssertTrue(getInfo.contains(version))
        XCTAssertTrue(getInfo.contains("conceptfab.com"))
        XCTAssertFalse(getInfo.contains("Kleniewski"))
    }

    func testHumanReadableDescriptionIsPresent() throws {
        let description = try XCTUnwrap(info["NSHumanReadableDescription"] as? String)
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.lowercased().contains("notch"))
    }

    func testApplicationCategory() throws {
        let category = try XCTUnwrap(info["LSApplicationCategoryType"] as? String)
        XCTAssertEqual(category, "public.app-category.utilities")
    }

    func testIsAgentApp() throws {
        let isUIElement = try XCTUnwrap(info["LSUIElement"] as? Bool)
        XCTAssertTrue(isUIElement)
    }

    func testHighResolutionCapable() throws {
        let highResolutionCapable = try XCTUnwrap(info["NSHighResolutionCapable"] as? Bool)
        XCTAssertTrue(highResolutionCapable)
    }

    func testRequiresNativeExecution() throws {
        let nativeOnly = try XCTUnwrap(info["LSRequiresNativeExecution"] as? Bool)
        XCTAssertTrue(nativeOnly, "NotchShelf is Apple Silicon only; refuse Rosetta translation")
    }

    func testArchitecturePriorityIsArm64Only() throws {
        let priority = try XCTUnwrap(info["LSArchitecturePriority"] as? [String])
        XCTAssertEqual(priority, ["arm64"])
    }
}

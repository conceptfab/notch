import XCTest
@testable import NotchShelf

@MainActor
final class AboutViewContentTests: XCTestCase {
    func testAboutLinksPointToConceptFab() {
        XCTAssertEqual(
            AboutPreferencesView.authorURL,
            URL(string: "https://conceptfab.com")
        )
        XCTAssertEqual(
            AboutPreferencesView.websiteURL,
            URL(string: "https://notchshelf.conceptfab.com")
        )
        XCTAssertEqual(
            AboutPreferencesView.buyMeACoffeeURL,
            URL(string: "https://www.buymeacoffee.com/conceptfab")
        )
    }

    func testAboutPlatformText() {
        XCTAssertEqual(
            AboutPreferencesView.platformDescription,
            "Apple Silicon Mac, macOS 26+"
        )
    }

    func testAboutTaglineIsNonEmpty() {
        XCTAssertFalse(AboutPreferencesView.tagline.isEmpty)
    }

    func testPreferencesWindowUsesCompactHeightThatFitsCompleteAboutContent() {
        XCTAssertEqual(PreferencesPanelMetrics.windowHeight, 520)
    }
}

import SwiftUI

@main
struct NotchShelfApp: App {
    var body: some Scene {
        // No main window — this is a menu-bar / notch agent app (LSUIElement).
        // The notch panel and menu bar item are created in a later task.
        Settings {
            EmptyView()
        }
    }
}

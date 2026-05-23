import SwiftUI

struct PreferencesRootView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralPreferencesView()
            }
            Tab("Shelf", systemImage: "tray.full") {
                ShelfPreferencesView()
            }
            Tab("About", systemImage: "info.circle") {
                AboutPreferencesView()
            }
        }
        .frame(
            width: PreferencesPanelMetrics.windowWidth,
            height: PreferencesPanelMetrics.windowHeight
        )
    }
}

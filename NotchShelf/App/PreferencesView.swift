import SwiftUI

struct PreferencesRootView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ShelfPreferencesView()
                .tabItem { Label("Shelf", systemImage: "tray.full") }

            AboutPreferencesView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 410)
    }
}

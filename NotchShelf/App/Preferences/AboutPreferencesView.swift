import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
            }

            Text("NotchShelf")
                .font(.title2.weight(.semibold))
            Text("Version \(version) (\(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            VStack(spacing: 4) {
                Text("Made by Michal Kleniewski")
                    .font(.callout)
                Text(copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("View License") {
                    if let url = URL(string: "https://opensource.org/license/mit") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Acknowledgements") {
                    let alert = NSAlert()
                    alert.messageText = "Acknowledgements"
                    alert.informativeText = "NotchShelf is built on Apple platform frameworks only. Thanks to the boring.notch project for the notch geometry research."
                    alert.runModal()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

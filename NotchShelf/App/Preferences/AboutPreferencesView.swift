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

    private var appIcon: NSImage {
        if
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        {
            return icon
        }

        if let icon = NSApp.applicationIconImage, icon.isValid {
            return icon
        }

        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    var body: some View {
        PreferencesPage {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text("NotchShelf")
                            .font(.title2.bold())

                        Text("Version \(version) (\(build))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(spacing: 6) {
                    Text("Made by Michal Kleniewski")
                        .font(.body)

                    Text(copyright)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "https://opensource.org/license/mit") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("View License")
                    }

                    Button {
                        showAcknowledgements()
                    } label: {
                        Text("Acknowledgements")
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
    }

    private func showAcknowledgements() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "NotchShelf is built on Apple platform frameworks only. Thanks to the boring.notch project for the notch geometry research."
        alert.runModal()
    }
}

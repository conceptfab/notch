import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    static let authorURL = URL(string: "https://conceptfab.com")!
    static let websiteURL = URL(string: "https://notchshelf.conceptfab.com")!
    static let buyMeACoffeeURL = URL(string: "https://www.buymeacoffee.com/conceptfab")!
    static let platformDescription = "Apple Silicon Mac, macOS 26+"
    static let tagline = "A shelf that lives in the macOS notch."

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
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
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("NotchShelf")
                        .font(.largeTitle.bold())
                    Text(Self.tagline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Version") {
                        Text(versionString).foregroundStyle(.secondary)
                    }
                    LabeledContent("Author") {
                        Link("conceptfab.com", destination: Self.authorURL)
                    }
                    LabeledContent("Website") {
                        Link("notchshelf.conceptfab.com", destination: Self.websiteURL)
                    }
                    LabeledContent("Icons") {
                        Text("MW Coffee").foregroundStyle(.secondary)
                    }
                    LabeledContent("Platform") {
                        Text(Self.platformDescription).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: 360)

                Text(copyright)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link(destination: Self.buyMeACoffeeURL) {
                    buyMeACoffeeButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buy Me a Coffee")
                .padding(.top, 2)

                HStack(spacing: 12) {
                    Button("View License") {
                        openBundledLicense()
                    }

                    Button("Acknowledgements") {
                        showAcknowledgements()
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
    }

    private var buyMeACoffeeButton: some View {
        Group {
            if
                let url = Bundle.main.url(forResource: "buy-me-a-coffee", withExtension: "png"),
                let image = NSImage(contentsOf: url)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 217, height: 60)
            } else {
                Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    .frame(minWidth: 180)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    private func openBundledLicense() {
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") {
            NSWorkspace.shared.open(url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "License file not found"
        alert.informativeText = "NotchShelf is distributed under the MIT License."
        alert.runModal()
    }

    private func showAcknowledgements() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = """
        NotchShelf is built on Apple platform frameworks only. Thanks to the \
        boring.notch project for the notch geometry research, and to \
        ConceptFab's sibling app Clank for the About-view layout.
        """
        alert.runModal()
    }
}

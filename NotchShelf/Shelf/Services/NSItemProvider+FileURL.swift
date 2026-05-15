import Foundation
import UniformTypeIdentifiers

extension NSItemProvider {
    /// Returns a file-system URL if this provider represents a file dragged from the filesystem.
    func extractFileURL() async -> URL? {
        guard hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return nil }
        return await loadFileURL(typeIdentifier: UTType.fileURL.identifier)
    }

    /// Loads a file URL for the given type identifier, handling the URL / Data / String
    /// shapes that different drag sources hand out.
    func loadFileURL(typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    AppLogger.drag.error("Error loading item for \(typeIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    cont.resume(returning: nil)
                    return
                }
                var resolved: URL?
                if let url = item as? URL {
                    resolved = url
                } else if let data = item as? Data {
                    if let string = String(data: data, encoding: .utf8) {
                        if let url = URL(string: string) {
                            resolved = url
                        } else if string.hasPrefix("/") {
                            resolved = URL(fileURLWithPath: string)
                        }
                    }
                    if resolved == nil {
                        resolved = Bookmark(data: data).resolveURL()
                    }
                } else if let string = item as? String {
                    if let url = URL(string: string) {
                        resolved = url
                    } else if string.hasPrefix("/") {
                        resolved = URL(fileURLWithPath: string)
                    }
                }
                cont.resume(returning: resolved)
            }
        }
    }
}

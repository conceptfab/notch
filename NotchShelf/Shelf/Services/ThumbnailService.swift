import AppKit
import Foundation
import QuickLookThumbnailing

/// Caching wrapper around `QLThumbnailGenerator`. Deduplicates concurrent requests
/// for the same file and size.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private var cache: [String: NSImage] = [:]
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private let generator = QLThumbnailGenerator.shared

    private init() {}

    func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let key = "\(url.path)_\(size.width)x\(size.height)"

        if let cached = cache[key] { return cached }
        if let pendingTask = pending[key] { return await pendingTask.value }

        let task = Task<NSImage?, Never> {
            let image = await generate(for: url, size: size)
            if let image { cache[key] = image }
            pending[key] = nil
            return image
        }
        pending[key] = task
        return await task.value
    }

    func clearCache() {
        cache.removeAll()
    }

    private func generate(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: scale, representationTypes: .all
        )
        request.iconMode = true
        return await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            generator.generateBestRepresentation(for: request) { representation, error in
                if let representation {
                    let cgImage = representation.cgImage
                    continuation.resume(returning: NSImage(
                        cgImage: cgImage,
                        size: NSSize(width: cgImage.width, height: cgImage.height)
                    ))
                } else {
                    if let error {
                        NSLog("Thumbnail error for \(url.path): \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

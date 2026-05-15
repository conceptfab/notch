import AppKit
import Foundation
import QuickLookThumbnailing

/// Caching wrapper around `QLThumbnailGenerator`. Deduplicates concurrent requests
/// for the same file and size, with bounded eviction for decoded images.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private let generator = QLThumbnailGenerator.shared
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        let cache = cache
        source.setEventHandler {
            cache.removeAllObjects()
        }
        source.resume()
        memoryPressureSource = source
    }

    func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let key = "\(url.path)_\(size.width)x\(size.height)"
        let nsKey = key as NSString

        if let cached = cache.object(forKey: nsKey) { return cached }
        if let pendingTask = pending[key] { return await pendingTask.value }

        let task = Task<NSImage?, Never> { await generate(for: url, size: size) }
        pending[key] = task
        let image = await task.value
        if let image {
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: nsKey, cost: cost)
        }
        pending[key] = nil
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
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
                        AppLogger.thumbnail.error("Thumbnail error for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

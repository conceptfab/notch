import AppKit
import UniformTypeIdentifiers

/// Watches global mouse events plus the drag pasteboard to detect a file drag, then
/// reports when that drag enters, moves within, leaves, or ends.
@MainActor
final class DragMonitor {
    var onEnterRegion: (() -> Void)?
    var onExitRegion: (() -> Void)?
    var onDragEnd: (() -> Void)?

    /// Supplies the current hit-region. Re-evaluated on every move so it can grow
    /// with the expanded shelf.
    private let regionProvider: () -> CGRect

    private var downMonitor: Any?
    private var draggedMonitor: Any?
    private var upMonitor: Any?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var pasteboardChangeCount = -1
    private var isDragging = false
    private var isFileDrag = false
    private var insideRegion = false
    private var lastLocation: CGPoint?

    init(regionProvider: @escaping () -> CGRect) {
        self.regionProvider = regionProvider
    }

    private func hasValidDragContent() -> Bool {
        dragPasteboard.types?.contains(.fileURL) ?? false
    }

    func startMonitoring() {
        stopMonitoring()

        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isDragging = true
            self.isFileDrag = false
            self.insideRegion = false
        }

        draggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            guard let self, self.isDragging else { return }

            let pasteboardChanged = self.dragPasteboard.changeCount != self.pasteboardChangeCount
            if pasteboardChanged && !self.isFileDrag && self.hasValidDragContent() {
                self.isFileDrag = true
            }
            guard self.isFileDrag else { return }

            let location = NSEvent.mouseLocation
            if self.lastLocation == location { return }
            self.lastLocation = location

            let nowInside = self.regionProvider().contains(location)
            if nowInside && !self.insideRegion {
                self.insideRegion = true
                self.onEnterRegion?()
            } else if !nowInside && self.insideRegion {
                self.insideRegion = false
                self.onExitRegion?()
            }
        }

        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self, self.isDragging else { return }
            self.isDragging = false
            self.isFileDrag = false
            self.insideRegion = false
            self.lastLocation = nil
            self.pasteboardChangeCount = -1
            self.onDragEnd?()
        }
    }

    func stopMonitoring() {
        for monitor in [downMonitor, draggedMonitor, upMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        downMonitor = nil
        draggedMonitor = nil
        upMonitor = nil
        isDragging = false
        isFileDrag = false
        insideRegion = false
        lastLocation = nil
    }

}

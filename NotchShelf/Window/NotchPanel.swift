import AppKit

/// Borderless, transparent panel pinned over the notch. It floats above normal
/// windows and stays visible across Spaces while keeping the app accessory-like.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        level = .mainMenu + 3
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        appearance = NSAppearance(named: .darkAqua)
    }

    /// Allow key status so the shelf can handle Delete, but never main status.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

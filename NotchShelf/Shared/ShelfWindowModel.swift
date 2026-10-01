import SwiftUI

/// Drives the notch window: shelf expansion, file-drag targeting, drop pulses, and
/// the shared animation curve.
@MainActor
final class ShelfWindowModel: ObservableObject {
    enum Expansion: Hashable {
        case collapsed
        case expanded
    }

    @Published var expansion: Expansion = .collapsed
    /// True while a file drag is hovering the notch or shelf region.
    @Published var dragTargeting: Bool = false
    /// Pulsed to `true` by the shelf drop handler so the drag pipeline knows a drop landed.
    @Published var dropEvent: Bool = false
    /// Notch rectangle of the notch screen. Refreshed by `NotchWindowController` when
    /// screen parameters change, so views and the drag monitor don't query `NSScreen`.
    @Published private(set) var notchGeometry: NotchGeometry = NotchGeometry.current()
    /// Incremented by app-level event handlers when the notch should emit a brief glow.
    @Published private(set) var glowPulse: Int = 0

    private var collapseTask: Task<Void, Never>?
    private var pendingGlowSound = false

    func expand() {
        collapseTask?.cancel()
        collapseTask = nil
        guard expansion != .expanded else { return }
        expansion = .expanded
    }

    func collapse() {
        collapseTask?.cancel()
        collapseTask = nil
        setDragTargeting(false)
        guard expansion != .collapsed else { return }
        expansion = .collapsed
    }

    func updateNotchGeometry(_ geometry: NotchGeometry) {
        guard notchGeometry != geometry else { return }
        notchGeometry = geometry
    }

    func setDragTargeting(_ isTargeting: Bool) {
        guard dragTargeting != isTargeting else { return }
        dragTargeting = isTargeting
    }

    func requestGlow(playSound: Bool = false) {
        glowPulse += 1
        if playSound {
            pendingGlowSound = true
        }
    }

    func consumePendingGlowSound() -> Bool {
        defer { pendingGlowSound = false }
        return pendingGlowSound
    }

    /// Collapses after `seconds` unless cancelled first, for example by `expand()`.
    func scheduleCollapse(after seconds: Double = 1.5) {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.collapse()
        }
    }
}

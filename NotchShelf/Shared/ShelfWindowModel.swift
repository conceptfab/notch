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
    /// Current visible shape size (width/height of the rendered NotchShelfShape).
    /// Published by `ContentView` whenever it recomputes layout. Consumed by
    /// `StackFileListPanelPresenter` so the stack drawer can anchor itself just
    /// below the shape, matching its width.
    @Published var shapeSize: CGSize = .zero

    private var collapseTask: Task<Void, Never>?

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

    func setDragTargeting(_ isTargeting: Bool) {
        guard dragTargeting != isTargeting else { return }
        dragTargeting = isTargeting
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

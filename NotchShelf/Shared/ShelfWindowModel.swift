import SwiftUI

/// Drives the notch window: shelf expansion, file-drag targeting, drop pulses, and
/// the shared animation curve.
@MainActor
final class ShelfWindowModel: ObservableObject {
    enum Expansion: Equatable {
        case collapsed
        case expanded
    }

    @Published var expansion: Expansion = .collapsed
    /// True while a file drag is hovering the notch or shelf region.
    @Published var dragTargeting: Bool = false
    /// Pulsed to `true` by the shelf drop handler so the drag pipeline knows a drop landed.
    @Published var dropEvent: Bool = false

    let animation: Animation = .spring(response: 0.35, dampingFraction: 0.85)

    private var collapseTask: Task<Void, Never>?

    func expand() {
        collapseTask?.cancel()
        collapseTask = nil
        expansion = .expanded
    }

    func collapse() {
        collapseTask?.cancel()
        collapseTask = nil
        dragTargeting = false
        expansion = .collapsed
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

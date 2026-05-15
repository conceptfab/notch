import Foundation

/// Unified load-lifecycle state used by `ShelfStore`. Replaces parallel `items` +
/// `isLoading` flags so callers can pattern-match a single source of truth.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

extension Loadable: Equatable where Value: Equatable {}

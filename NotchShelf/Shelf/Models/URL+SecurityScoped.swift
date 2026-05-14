import Foundation

extension URL {
    /// Runs `accessor` with security-scoped access started for the duration of the call.
    func accessSecurityScopedResource<Value>(accessor: (URL) throws -> Value) rethrows -> Value {
        let didStart = startAccessingSecurityScopedResource()
        defer { if didStart { stopAccessingSecurityScopedResource() } }
        return try accessor(self)
    }

    /// Async variant of `accessSecurityScopedResource`.
    func accessSecurityScopedResource<Value>(accessor: (URL) async throws -> Value) async rethrows -> Value {
        let didStart = startAccessingSecurityScopedResource()
        defer { if didStart { stopAccessingSecurityScopedResource() } }
        return try await accessor(self)
    }
}

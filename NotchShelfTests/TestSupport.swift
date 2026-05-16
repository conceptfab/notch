import Foundation
@testable import NotchShelf

struct TempDir {
    let url: URL

    static func make() throws -> TempDir {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchShelfTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return TempDir(url: url)
    }
}

extension URL {
    @discardableResult
    func touch() throws -> URL {
        try Data().write(to: self)
        return self
    }
}

func makeTestUserDefaults() -> UserDefaults {
    let suiteName = "NotchShelfTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    registerPreferenceDefaults(in: defaults)
    return defaults
}

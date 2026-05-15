import Foundation

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

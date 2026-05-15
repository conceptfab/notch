import os.log

/// Centralized `os.Logger` namespace for filtering NotchShelf logs in Console.app.
enum AppLogger {
    private static let subsystem = "com.notchshelf.NotchShelf"

    static let bookmark = Logger(subsystem: subsystem, category: "bookmark")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let thumbnail = Logger(subsystem: subsystem, category: "thumbnail")
    static let drag = Logger(subsystem: subsystem, category: "drag")
    static let shelf = Logger(subsystem: subsystem, category: "shelf")
}

enum UserDefaultsKey {
    static let copyOnDrag = "copyOnDrag"
}

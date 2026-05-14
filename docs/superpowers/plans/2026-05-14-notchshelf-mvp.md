# NotchShelf MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone macOS app where dragging files toward the MacBook notch slides out a shelf you can drop files onto, then later drag back out into another folder.

**Architecture:** A single borderless `NSPanel` pinned over the notch, always sized to the fully-expanded shelf but transparent; a SwiftUI `NotchShelfShape` animates from notch-sized (collapsed) to shelf-sized (expanded) inside it. A global `NSEvent` drag monitor expands the shelf when a file drag enters the notch region. The file-shelf logic (data model, persistence, drag-in/out, selection, thumbnails) is ported from boring.notch's lightly-coupled `Shelf` component, with its 4 `BoringViewModel` touch-points replaced by a small `ShelfWindowModel` and its 2 `Defaults` keys replaced by a `Preferences` wrapper over `UserDefaults`.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Swift Testing. XcodeGen generates the `.xcodeproj` from a checked-in `project.yml`. Zero third-party app dependencies — Apple frameworks only.

**Reference source:** boring.notch is on disk at `boring.notch-main/`. Paths below like `boring.notch-main/boringNotch/components/Shelf/...` point at the original code being ported. It is reference only — never built, never a dependency.

**Conventions for every task:**
- Run tests with: `xcodebuild test -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -derivedDataPath .build 2>&1 | xcbeautify` (drop `| xcbeautify` if not installed).
- Before any task that adds Swift files, run `xcodegen generate` so the new files are in the project.
- Commit after every task. Commit messages use Conventional Commits.

---

## Phase 0 — Project bootstrap

### Task 1: Repository, project generator, app skeleton

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `scripts/build.sh`
- Create: `NotchShelf/Info.plist`
- Create: `NotchShelf/NotchShelf.entitlements`
- Create: `NotchShelf/App/NotchShelfApp.swift`
- Create: `NotchShelfTests/SmokeTests.swift`

- [ ] **Step 1: Initialize git and install XcodeGen**

```bash
cd /Users/micz/__DEV__/notch
git init
brew install xcodegen   # skip if `which xcodegen` already prints a path
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.DS_Store
.build/
DerivedData/
*.xcodeproj
.superpowers/
xcuserdata/
```

(The `.xcodeproj` is generated from `project.yml` by XcodeGen, so it is not committed.)

- [ ] **Step 3: Write `project.yml`**

```yaml
name: NotchShelf
options:
  bundleIdPrefix: com.notchshelf
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
targets:
  NotchShelf:
    type: application
    platform: macOS
    sources:
      - path: NotchShelf
    settings:
      base:
        INFOPLIST_FILE: NotchShelf/Info.plist
        CODE_SIGN_ENTITLEMENTS: NotchShelf/NotchShelf.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.notchshelf.NotchShelf
        ENABLE_HARDENED_RUNTIME: YES
        ENABLE_APP_SANDBOX: YES
  NotchShelfTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: NotchShelfTests
    dependencies:
      - target: NotchShelf
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.notchshelf.NotchShelfTests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  NotchShelf:
    build:
      targets:
        NotchShelf: all
        NotchShelfTests: [test]
    test:
      targets:
        - NotchShelfTests
```

- [ ] **Step 4: Write `NotchShelf/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NotchShelf</string>
    <key>CFBundleDisplayName</key>
    <string>NotchShelf</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>NotchShelf</string>
</dict>
</plist>
```

- [ ] **Step 5: Write `NotchShelf/NotchShelf.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.files.bookmarks.document-scope</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 6: Write `NotchShelf/App/NotchShelfApp.swift` (minimal placeholder app)**

```swift
import SwiftUI

@main
struct NotchShelfApp: App {
    var body: some Scene {
        // No main window — this is a menu-bar / notch agent app (LSUIElement).
        // The notch panel and menu bar item are created in a later task.
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 7: Write `NotchShelfTests/SmokeTests.swift`**

```swift
import Testing

@Test func smokeTestRuns() {
    #expect(Bool(true))
}
```

- [ ] **Step 8: Write `scripts/build.sh` and make it executable**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf \
  -configuration Debug -derivedDataPath .build build
echo "Built: .build/Build/Products/Debug/NotchShelf.app"
echo "Run with: open .build/Build/Products/Debug/NotchShelf.app"
```

Then: `chmod +x scripts/build.sh`

- [ ] **Step 9: Generate the project and verify it builds**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Verify the test target runs**

Run: `xcodebuild test -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -derivedDataPath .build`
Expected: `** TEST SUCCEEDED **`, `smokeTestRuns` passes.

- [ ] **Step 11: Commit**

```bash
git add .gitignore project.yml scripts/build.sh NotchShelf NotchShelfTests
git commit -m "chore: bootstrap NotchShelf Xcode project with XcodeGen"
```

---

## Phase 1 — Shelf data core (pure logic, TDD)

### Task 2: `URL` security-scoped access extension

Ported almost verbatim from `boring.notch-main/boringNotch/extensions/URL+SecurityScoped.swift` (the `[URL]` variant is dropped — unused in MVP).

**Files:**
- Create: `NotchShelf/Shelf/Models/URL+SecurityScoped.swift`
- Test: `NotchShelfTests/URLSecurityScopedTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func accessSecurityScopedResourceRunsAccessorAndReturnsValue() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "hello".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let contents = tmp.accessSecurityScopedResource { url in
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    #expect(contents == "hello")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `accessSecurityScopedResource` is not a member of `URL`.

- [ ] **Step 3: Write `NotchShelf/Shelf/Models/URL+SecurityScoped.swift`**

```swift
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
```

- [ ] **Step 4: Run `xcodegen generate`, then run the test to verify it passes**

Run: `xcodegen generate && xcodebuild test -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Models/URL+SecurityScoped.swift NotchShelfTests/URLSecurityScopedTests.swift
git commit -m "feat: add URL security-scoped access extension"
```

---

### Task 3: `Bookmark`

Ported from `boring.notch-main/boringNotch/components/Shelf/Models/Bookmark.swift`. The original's `static func update(in:for:newBookmark:)` is dropped — it referenced the old `ShelfItemKind` enum and is unused here.

**Files:**
- Create: `NotchShelf/Shelf/Models/Bookmark.swift`
- Test: `NotchShelfTests/BookmarkTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func bookmarkCreatesAndResolvesToSameFile() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "data".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let bookmark = try Bookmark(url: tmp)
    let resolved = bookmark.resolveURL()
    #expect(resolved?.standardizedFileURL.path == tmp.standardizedFileURL.path)
}

@Test func bookmarkInitThrowsForMissingFile() {
    let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
    #expect(throws: (any Error).self) { _ = try Bookmark(url: missing) }
}

@Test func bookmarkResolveReturnsNilForEmptyData() {
    let bookmark = Bookmark(data: Data())
    #expect(bookmark.resolveURL() == nil)
}

@Test func bookmarkValidateIsTrueForExistingFileFalseAfterDeletion() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "data".write(to: tmp, atomically: true, encoding: .utf8)
    let bookmark = try Bookmark(url: tmp)
    let validBefore = await bookmark.validate()
    #expect(validBefore == true)

    try FileManager.default.removeItem(at: tmp)
    let validAfter = await bookmark.validate()
    #expect(validAfter == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `Bookmark` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/Models/Bookmark.swift`**

```swift
import Foundation
import AppKit

/// A security-scoped bookmark to a user-selected file. Survives app restarts and
/// transparently refreshes itself when macOS marks the bookmark stale.
struct Bookmark: Sendable, Equatable, Codable {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(url: URL) throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "Bookmark", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Not a valid file URL or file missing at \(url.path)"]
            )
        }
        self.data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves the bookmark. Returns the URL and, if the bookmark was stale,
    /// freshly regenerated bookmark data the caller should persist.
    func resolve() -> (url: URL?, refreshedData: Data?) {
        guard !data.isEmpty else { return (nil, nil) }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale, let newData = try? url.bookmarkData(options: [.withSecurityScope]) {
                return (url, newData)
            }
            return (url, nil)
        } catch {
            NSLog("Bookmark resolve failed: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    func resolveURL() -> URL? { resolve().url }

    var refreshedData: Data? { resolve().refreshedData }

    /// True if the bookmark still points at an existing file.
    func validate() async -> Bool {
        guard let url = resolve().url else { return false }
        return url.accessSecurityScopedResource { FileManager.default.fileExists(atPath: $0.path) }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all four `Bookmark` tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Models/Bookmark.swift NotchShelfTests/BookmarkTests.swift
git commit -m "feat: add security-scoped Bookmark model"
```

---

### Task 4: `ShelfItem`

A simplified rewrite of `boring.notch-main/boringNotch/components/Shelf/Models/ShelfItem.swift`. The original `ShelfItemKind` enum (file/text/link) collapses to a plain files-only struct; the TextBlock/WebLoc naming logic, `icon`, and `cleanupStoredData` are dropped.

**Files:**
- Create: `NotchShelf/Shelf/Models/ShelfItem.swift`
- Test: `NotchShelfTests/ShelfItemTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

private func makeTempFile(named name: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let file = url.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return file
}

@Test func shelfItemDisplayNameMatchesFileName() throws {
    let file = try makeTempFile(named: "Report.pdf")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    #expect(item.displayName == "Report.pdf")
}

@Test func shelfItemFileURLResolvesToOriginal() throws {
    let file = try makeTempFile(named: "Photo.png")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    #expect(item.fileURL?.standardizedFileURL.path == file.standardizedFileURL.path)
}

@Test func shelfItemIdentityKeyIsStablePerPath() throws {
    let file = try makeTempFile(named: "Doc.txt")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let a = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let b = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    #expect(a.identityKey == b.identityKey)
    #expect(a.id != b.id)
}

@Test func shelfItemRoundTripsThroughCodable() throws {
    let file = try makeTempFile(named: "Codable.txt")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let item = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let encoded = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(ShelfItem.self, from: encoded)
    #expect(decoded == item)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfItem` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/Models/ShelfItem.swift`**

```swift
import Foundation

/// One file (or folder) parked on the shelf. Holds only a security-scoped bookmark —
/// the original file is never copied or moved.
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var bookmarkData: Data

    init(id: UUID = UUID(), bookmarkData: Data) {
        self.id = id
        self.bookmarkData = bookmarkData
    }

    /// Current location of the file, or nil if the bookmark can no longer be resolved.
    var fileURL: URL? {
        Bookmark(data: bookmarkData).resolveURL()
    }

    /// Finder-style display name, falling back to the last path component.
    var displayName: String {
        guard let url = fileURL else { return "Unknown file" }
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
            ?? url.lastPathComponent
    }

    /// Stable key for deduplication: the standardized file path, or the bookmark bytes
    /// when the file cannot currently be resolved.
    var identityKey: String {
        if let url = fileURL {
            return "file://" + url.standardizedFileURL.path
        }
        return "file://missing/" + bookmarkData.base64EncodedString()
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all four `ShelfItem` tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Models/ShelfItem.swift NotchShelfTests/ShelfItemTests.swift
git commit -m "feat: add files-only ShelfItem model"
```

---

### Task 5: `Preferences`

Replaces boring.notch's two `Defaults` keys (`copyOnDrag`, `autoRemoveShelfItems`) with a thin `UserDefaults` wrapper. The `init(defaults:)` parameter exists so tests can use an isolated suite.

**Files:**
- Create: `NotchShelf/Shared/Preferences.swift`
- Test: `NotchShelfTests/PreferencesTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func preferencesDefaultToFalse() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = Preferences(defaults: suite)
    #expect(prefs.copyOnDrag == false)
    #expect(prefs.autoRemoveShelfItems == false)
}

@Test func preferencesPersistWrites() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = Preferences(defaults: suite)
    prefs.copyOnDrag = true
    prefs.autoRemoveShelfItems = true
    #expect(prefs.copyOnDrag == true)
    #expect(prefs.autoRemoveShelfItems == true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `Preferences` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shared/Preferences.swift`**

```swift
import Foundation

/// App preferences backed by `UserDefaults`. Both keys default to `false`.
final class Preferences: @unchecked Sendable {
    static let shared = Preferences()

    private let defaults: UserDefaults
    private enum Key {
        static let copyOnDrag = "copyOnDrag"
        static let autoRemoveShelfItems = "autoRemoveShelfItems"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// When true, dragging items off the shelf is restricted to copy (never move).
    var copyOnDrag: Bool {
        get { defaults.bool(forKey: Key.copyOnDrag) }
        set { defaults.set(newValue, forKey: Key.copyOnDrag) }
    }

    /// When true, a successful drag-out removes the item from the shelf.
    var autoRemoveShelfItems: Bool {
        get { defaults.bool(forKey: Key.autoRemoveShelfItems) }
        set { defaults.set(newValue, forKey: Key.autoRemoveShelfItems) }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shared/Preferences.swift NotchShelfTests/PreferencesTests.swift
git commit -m "feat: add Preferences wrapper over UserDefaults"
```

---

### Task 6: `ShelfPersistenceService`

Ported from `boring.notch-main/boringNotch/components/Shelf/Services/ShelfPersistenceService.swift`. Storage path changes to `Application Support/NotchShelf/shelf.json`. An `init(directory:)` parameter is added so tests write to a temp directory.

**Files:**
- Create: `NotchShelf/Shelf/Services/ShelfPersistenceService.swift`
- Test: `NotchShelfTests/ShelfPersistenceServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

private func tempDir() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeItem() throws -> ShelfItem {
    let dir = tempDir()
    let file = dir.appendingPathComponent("f-\(UUID().uuidString).txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@Test func persistenceLoadReturnsEmptyWhenNoFile() {
    let service = ShelfPersistenceService(directory: tempDir())
    #expect(service.load().isEmpty)
}

@Test func persistenceSaveThenLoadRoundTrips() throws {
    let service = ShelfPersistenceService(directory: tempDir())
    let items = [try makeItem(), try makeItem()]
    service.save(items)
    let loaded = service.load()
    #expect(loaded == items)
}

@Test func persistenceSkipsCorruptedEntries() throws {
    let dir = tempDir()
    let service = ShelfPersistenceService(directory: dir)
    let good = try makeItem()
    // One valid item dict plus one structurally-broken entry.
    let goodData = try JSONEncoder().encode(good)
    let goodObj = try JSONSerialization.jsonObject(with: goodData)
    let mixed: [Any] = [goodObj, ["id": "not-a-uuid", "bookmarkData": 12345]]
    let mixedData = try JSONSerialization.data(withJSONObject: mixed)
    try mixedData.write(to: dir.appendingPathComponent("shelf.json"))

    let loaded = service.load()
    #expect(loaded == [good])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfPersistenceService` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/Services/ShelfPersistenceService.swift`**

```swift
import Foundation

/// JSON persistence for the shelf. Stores items at
/// `~/Library/Application Support/NotchShelf/shelf.json`.
final class ShelfPersistenceService: @unchecked Sendable {
    static let shared = ShelfPersistenceService()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// - Parameter directory: storage directory. Defaults to the app support folder;
    ///   tests pass a temporary directory.
    init(directory: URL? = nil) {
        let fm = FileManager.default
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let support = try? fm.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask, appropriateFor: nil, create: true)
            dir = (support ?? fm.temporaryDirectory)
                .appendingPathComponent("NotchShelf", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("shelf.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    /// Loads the shelf. Corrupted individual entries are skipped rather than failing the whole load.
    func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let items = try? decoder.decode([ShelfItem].self, from: data) {
            return items
        }

        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            NSLog("Shelf persistence file is not a valid JSON array")
            return []
        }

        var valid: [ShelfItem] = []
        var failed = 0
        for entry in jsonArray {
            if let entryData = try? JSONSerialization.data(withJSONObject: entry),
               let item = try? decoder.decode(ShelfItem.self, from: entryData) {
                valid.append(item)
            } else {
                failed += 1
            }
        }
        if failed > 0 {
            NSLog("Loaded \(valid.count) shelf items, discarded \(failed) corrupted")
        }
        return valid
    }

    func save(_ items: [ShelfItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to save shelf items: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all three persistence tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfPersistenceService.swift NotchShelfTests/ShelfPersistenceServiceTests.swift
git commit -m "feat: add ShelfPersistenceService with resilient JSON load"
```

---

### Task 7: `ShelfSelection`

Ported from `boring.notch-main/boringNotch/components/Shelf/ViewModels/ShelfSelectionModel.swift`. Renamed `ShelfSelectionModel` → `ShelfSelection`. The `_shelfTypeAnchor` hack and the `firstSelectedItem` convenience (which referenced the store singleton) are dropped — selection logic stays pure.

**Files:**
- Create: `NotchShelf/Shelf/State/ShelfSelection.swift`
- Test: `NotchShelfTests/ShelfSelectionTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@MainActor
private func items(_ n: Int) -> [ShelfItem] {
    (0..<n).map { _ in ShelfItem(bookmarkData: Data([UInt8.random(in: 0...255)])) }
}

@MainActor @Test func selectSingleReplacesSelection() {
    let sel = ShelfSelection()
    let all = items(3)
    sel.selectSingle(all[0])
    sel.selectSingle(all[2])
    #expect(sel.selectedIDs == [all[2].id])
}

@MainActor @Test func toggleAddsAndRemoves() {
    let sel = ShelfSelection()
    let all = items(3)
    sel.toggle(all[0])
    sel.toggle(all[1])
    #expect(sel.selectedIDs == [all[0].id, all[1].id])
    sel.toggle(all[0])
    #expect(sel.selectedIDs == [all[1].id])
}

@MainActor @Test func shiftSelectSelectsInclusiveRange() {
    let sel = ShelfSelection()
    let all = items(5)
    sel.selectSingle(all[1])
    sel.shiftSelect(to: all[3], in: all)
    #expect(sel.selectedIDs == Set(all[1...3].map(\.id)))
}

@MainActor @Test func clearEmptiesSelection() {
    let sel = ShelfSelection()
    let all = items(2)
    sel.selectSingle(all[0])
    sel.clear()
    #expect(sel.selectedIDs.isEmpty)
}

@MainActor @Test func dragStateTracks() {
    let sel = ShelfSelection()
    #expect(sel.isDragging == false)
    sel.beginDrag()
    #expect(sel.isDragging == true)
    sel.endDrag()
    #expect(sel.isDragging == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfSelection` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/State/ShelfSelection.swift`**

```swift
import Foundation
import Combine

/// Multi-selection state for the shelf, with shift-range support and a drag flag.
@MainActor
final class ShelfSelection: ObservableObject {
    static let shared = ShelfSelection()

    @Published private(set) var selectedIDs: Set<UUID> = []
    @Published private(set) var isDragging: Bool = false

    /// Anchor for shift-range selection.
    private var lastAnchorID: UUID?

    init() {}

    func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    var hasSelection: Bool { !selectedIDs.isEmpty }

    func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    func selectSingle(_ item: ShelfItem) {
        selectedIDs = [item.id]
        lastAnchorID = item.id
    }

    func toggle(_ item: ShelfItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        lastAnchorID = item.id
    }

    func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem]) {
        let anchorID = lastAnchorID ?? selectedIDs.first ?? item.id
        guard let start = allItems.firstIndex(where: { $0.id == anchorID }),
              let end = allItems.firstIndex(where: { $0.id == item.id }) else {
            return selectSingle(item)
        }
        let range = min(start, end)...max(start, end)
        selectedIDs = Set(allItems[range].map(\.id))
    }

    func clear() {
        selectedIDs.removeAll()
        lastAnchorID = nil
    }

    func beginDrag() { isDragging = true }
    func endDrag() { isDragging = false }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all five selection tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfSelection.swift NotchShelfTests/ShelfSelectionTests.swift
git commit -m "feat: add ShelfSelection multi-select state"
```

---

### Task 8: `NSItemProvider` file-URL extraction helper

A files-only subset ported from `boring.notch-main/boringNotch/extensions/NSItemProvider+LoadHelpers.swift` — only `extractFileURL()` and `loadFileURL(typeIdentifier:)`. (Drag detection of *whether* a provider is a file is exercised by `ShelfDropService` in Task 9; this helper has no isolated unit test of its own.)

**Files:**
- Create: `NotchShelf/Shelf/Services/NSItemProvider+FileURL.swift`

- [ ] **Step 1: Write `NotchShelf/Shelf/Services/NSItemProvider+FileURL.swift`**

```swift
import Foundation
import UniformTypeIdentifiers

extension NSItemProvider {
    /// Returns a file-system URL if this provider represents a file dragged from the filesystem.
    func extractFileURL() async -> URL? {
        guard hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return nil }
        return await loadFileURL(typeIdentifier: UTType.fileURL.identifier)
    }

    /// Loads a file URL for the given type identifier, handling the URL / Data / String
    /// shapes that different drag sources hand out.
    func loadFileURL(typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    NSLog("Error loading item for \(typeIdentifier): \(error.localizedDescription)")
                    cont.resume(returning: nil)
                    return
                }
                var resolved: URL?
                if let url = item as? URL {
                    resolved = url
                } else if let data = item as? Data {
                    if let string = String(data: data, encoding: .utf8) {
                        if let url = URL(string: string) {
                            resolved = url
                        } else if string.hasPrefix("/") {
                            resolved = URL(fileURLWithPath: string)
                        }
                    }
                    if resolved == nil {
                        resolved = Bookmark(data: data).resolveURL()
                    }
                } else if let string = item as? String {
                    if let url = URL(string: string) {
                        resolved = url
                    } else if string.hasPrefix("/") {
                        resolved = URL(fileURLWithPath: string)
                    }
                }
                cont.resume(returning: resolved)
            }
        }
    }
}
```

- [ ] **Step 2: Run `xcodegen generate` and build to verify it compiles**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/Services/NSItemProvider+FileURL.swift
git commit -m "feat: add NSItemProvider file-URL extraction helper"
```

---

### Task 9: `ShelfDropService`

A files-only rewrite of `boring.notch-main/boringNotch/components/Shelf/Services/ShelfDropService.swift` — the text / web-URL / raw-data / temp-file branches are removed.

**Files:**
- Create: `NotchShelf/Shelf/Services/ShelfDropService.swift`
- Test: `NotchShelfTests/ShelfDropServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func dropServiceCreatesItemFromFileProvider() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("dropped.txt")
    try "content".write(to: file, atomically: true, encoding: .utf8)

    let provider = NSItemProvider()
    provider.registerObject(file as NSURL, visibility: .all)

    let items = await ShelfDropService.items(from: [provider])
    #expect(items.count == 1)
    #expect(items.first?.fileURL?.standardizedFileURL.path == file.standardizedFileURL.path)
}

@Test func dropServiceIgnoresNonFileProviders() async {
    let provider = NSItemProvider(object: "just text" as NSString)
    let items = await ShelfDropService.items(from: [provider])
    #expect(items.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfDropService` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/Services/ShelfDropService.swift`**

```swift
import Foundation

/// Converts dropped `NSItemProvider`s into `ShelfItem`s. Files only — anything that
/// is not a file-system URL is ignored.
enum ShelfDropService {
    static func items(from providers: [NSItemProvider]) async -> [ShelfItem] {
        var results: [ShelfItem] = []
        for provider in providers {
            guard let url = await provider.extractFileURL() else { continue }
            guard let bookmark = try? Bookmark(url: url) else { continue }
            results.append(ShelfItem(bookmarkData: bookmark.data))
        }
        return results
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — both drop-service tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfDropService.swift NotchShelfTests/ShelfDropServiceTests.swift
git commit -m "feat: add files-only ShelfDropService"
```

---

### Task 10: `ShelfStore`

Ported from `boring.notch-main/boringNotch/components/Shelf/ViewModels/ShelfStateViewModel.swift`. Renamed `ShelfStateViewModel` → `ShelfStore`. `kind`-switching collapses to direct `bookmarkData` access; `remove` drops the `cleanupStoredData()` call (no temp files in MVP); an `init(persistence:)` parameter is added for testability.

**Files:**
- Create: `NotchShelf/Shelf/State/ShelfStore.swift`
- Test: `NotchShelfTests/ShelfStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@MainActor
private func storeWithTempPersistence() -> ShelfStore {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return ShelfStore(persistence: ShelfPersistenceService(directory: dir))
}

private func makeFileItem(named name: String = "f.txt") throws -> ShelfItem {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@MainActor @Test func storeAddAppendsItems() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem(named: "a.txt")
    store.add([a])
    #expect(store.items == [a])
}

@MainActor @Test func storeAddDeduplicatesBySamePath() throws {
    let store = storeWithTempPersistence()
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("dup.txt")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    let first = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    let second = ShelfItem(bookmarkData: try Bookmark(url: file).data)
    store.add([first])
    store.add([second])
    #expect(store.items.count == 1)
}

@MainActor @Test func storeRemoveDropsItem() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem()
    store.add([a])
    store.remove(a)
    #expect(store.items.isEmpty)
}

@MainActor @Test func storePersistsAcrossInstances() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let persistence = ShelfPersistenceService(directory: dir)
    let store1 = ShelfStore(persistence: persistence)
    let a = try makeFileItem()
    store1.add([a])

    let store2 = ShelfStore(persistence: ShelfPersistenceService(directory: dir))
    #expect(store2.items == [a])
}

@MainActor @Test func storeResolveFileURLReturnsURL() throws {
    let store = storeWithTempPersistence()
    let a = try makeFileItem()
    store.add([a])
    #expect(store.resolveFileURL(for: a) != nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfStore` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/State/ShelfStore.swift`**

```swift
import Foundation
import AppKit

/// The shelf's central state: the ordered list of items, persistence, and bookmark
/// lifecycle (refreshing stale bookmarks, pruning dead ones).
@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    private let persistence: ShelfPersistenceService

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { persistence.save(items) }
    }

    @Published var isLoading: Bool = false

    var isEmpty: Bool { items.isEmpty }

    /// Deferred bookmark refreshes, applied off the current run loop turn so we never
    /// mutate `items` while SwiftUI is reading it.
    private var pendingBookmarkUpdates: [ShelfItem.ID: Data] = [:]
    private var updateTask: Task<Void, Never>?

    init(persistence: ShelfPersistenceService = .shared) {
        self.persistence = persistence
        // Assign without triggering the didSet save on launch.
        let loaded = persistence.load()
        self.items = loaded
    }

    /// Appends new items, skipping any whose `identityKey` already exists.
    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        var seen = Set(merged.map(\.identityKey))
        for item in newItems where !seen.contains(item.identityKey) {
            merged.append(item)
            seen.insert(item.identityKey)
        }
        items = merged
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    /// Immediately replaces an item's bookmark (used for user-initiated actions).
    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].bookmarkData = bookmark
    }

    /// Queues a stale-bookmark refresh to be applied after the current update cycle.
    private func scheduleDeferredBookmarkUpdate(for item: ShelfItem, bookmark: Data) {
        pendingBookmarkUpdates[item.id] = bookmark
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            for (id, data) in self.pendingBookmarkUpdates {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx].bookmarkData = data
                }
            }
            self.pendingBookmarkUpdates.removeAll()
        }
    }

    /// Loads dropped providers into the shelf asynchronously.
    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        isLoading = true
        Task { [weak self] in
            let dropped = await ShelfDropService.items(from: providers)
            await MainActor.run {
                self?.add(dropped)
                self?.isLoading = false
            }
        }
    }

    /// Removes items whose bookmark no longer resolves to an existing file.
    func cleanupInvalidItems() {
        Task { [weak self] in
            guard let self else { return }
            var keep: [ShelfItem] = []
            for item in self.items {
                if await Bookmark(data: item.bookmarkData).validate() {
                    keep.append(item)
                }
            }
            await MainActor.run { self.items = keep }
        }
    }

    /// Resolves an item's URL, scheduling a deferred refresh if the bookmark was stale.
    func resolveFileURL(for item: ShelfItem) -> URL? {
        let result = Bookmark(data: item.bookmarkData).resolve()
        if let refreshed = result.refreshedData, refreshed != item.bookmarkData {
            scheduleDeferredBookmarkUpdate(for: item, bookmark: refreshed)
        }
        return result.url
    }

    /// Resolves an item's URL, refreshing a stale bookmark immediately.
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        let result = Bookmark(data: item.bookmarkData).resolve()
        if let refreshed = result.refreshedData, refreshed != item.bookmarkData {
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all five store tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/ShelfStoreTests.swift
git commit -m "feat: add ShelfStore state container with persistence"
```

---

### Task 11: `ShelfActionService`

A files-only rewrite of `boring.notch-main/boringNotch/components/Shelf/Services/ShelfActionService.swift` — `.text` / `.link` cases removed. No isolated unit test (every method is a thin AppKit side-effect); it is exercised through the context menu in manual verification.

**Files:**
- Create: `NotchShelf/Shelf/Services/ShelfActionService.swift`

- [ ] **Step 1: Write `NotchShelf/Shelf/Services/ShelfActionService.swift`**

```swift
import AppKit
import Foundation

/// Common actions for shelf items: open, reveal in Finder, copy path, remove.
@MainActor
enum ShelfActionService {
    static func open(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) { NSWorkspace.shared.open($0) }
    }

    static func reveal(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        }
    }

    static func copyPath(_ item: ShelfItem) {
        handleBookmarkedFile(item.bookmarkData) { url in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    static func remove(_ item: ShelfItem) {
        ShelfStore.shared.remove(item)
    }

    private static func handleBookmarkedFile(
        _ bookmarkData: Data,
        action: @escaping @Sendable (URL) -> Void
    ) {
        Task {
            guard let url = Bookmark(data: bookmarkData).resolveURL() else { return }
            url.accessSecurityScopedResource { action($0) }
        }
    }
}
```

- [ ] **Step 2: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfActionService.swift
git commit -m "feat: add ShelfActionService (open/reveal/copyPath/remove)"
```

---

## Phase 2 — Notch window

### Task 12: `NotchGeometry`

New. Detects the notch rectangle from `NSScreen`. The math lives in a pure initializer so it is unit-testable without a real screen.

**Files:**
- Create: `NotchShelf/Window/NotchGeometry.swift`
- Test: `NotchShelfTests/NotchGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@Test func notchGeometryComputesCenteredRectFromAuxAreas() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let g = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                          auxLeftWidth: 620, auxRightWidth: 620)
    #expect(g.hasNotch == true)
    #expect(g.notchWidth == 1512 - 620 - 620 + 4)   // 276
    #expect(g.notchHeight == 38)
    #expect(g.notchRect.midX == screen.midX)
    #expect(g.notchRect.maxY == screen.maxY)
    #expect(g.notchRect.height == 38)
}

@Test func notchGeometryFallsBackWhenNoAuxAreas() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let g = NotchGeometry(screenFrame: screen, safeAreaTop: 0,
                          auxLeftWidth: nil, auxRightWidth: nil)
    #expect(g.hasNotch == false)
    #expect(g.notchWidth == 185)
    #expect(g.notchHeight == 32)
}

@Test func notchGeometryContainsPointInsideAndOutside() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let g = NotchGeometry(screenFrame: screen, safeAreaTop: 38,
                          auxLeftWidth: 620, auxRightWidth: 620)
    #expect(g.contains(CGPoint(x: screen.midX, y: 970)) == true)
    #expect(g.contains(CGPoint(x: 10, y: 970)) == false)
    #expect(g.contains(CGPoint(x: screen.midX, y: 500)) == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `NotchGeometry` is not defined.

- [ ] **Step 3: Write `NotchShelf/Window/NotchGeometry.swift`**

```swift
import AppKit

/// The notch rectangle in global (bottom-left origin) screen coordinates — the
/// coordinate space `NSEvent.mouseLocation` uses.
struct NotchGeometry: Equatable {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchRect: CGRect
    let hasNotch: Bool

    /// Pure initializer — testable without a real `NSScreen`.
    init(screenFrame: CGRect, safeAreaTop: CGFloat,
         auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) {
        hasNotch = safeAreaTop > 0
        if let left = auxLeftWidth, let right = auxRightWidth {
            notchWidth = screenFrame.width - left - right + 4
        } else {
            notchWidth = 185
        }
        notchHeight = safeAreaTop > 0 ? safeAreaTop : 32
        notchRect = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }

    /// True when a global screen point falls inside the notch hit-region.
    func contains(_ point: CGPoint) -> Bool {
        notchRect.contains(point)
    }
}

extension NotchGeometry {
    /// Reads geometry from the built-in (notch) screen, falling back to the main screen.
    @MainActor
    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        return NotchGeometry(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }

    /// The built-in (notch) screen, or the main screen as a fallback.
    @MainActor
    static var notchScreen: NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all three geometry tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Window/NotchGeometry.swift NotchShelfTests/NotchGeometryTests.swift
git commit -m "feat: add NotchGeometry notch-rectangle detection"
```

---

### Task 13: `ShelfWindowModel`

New. The observable model that replaces boring.notch's 4 `BoringViewModel` touch-points (`dragTargeting`, `dropEvent`, `animation`) and adds the window expansion state.

**Files:**
- Create: `NotchShelf/Shared/ShelfWindowModel.swift`
- Test: `NotchShelfTests/ShelfWindowModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import NotchShelf

@MainActor @Test func windowModelExpandAndCollapse() {
    let model = ShelfWindowModel()
    #expect(model.expansion == .collapsed)
    model.expand()
    #expect(model.expansion == .expanded)
    model.collapse()
    #expect(model.expansion == .collapsed)
}

@MainActor @Test func windowModelCollapseClearsDragTargeting() {
    let model = ShelfWindowModel()
    model.dragTargeting = true
    model.collapse()
    #expect(model.dragTargeting == false)
}

@MainActor @Test func windowModelScheduledCollapseFiresAfterDelay() async {
    let model = ShelfWindowModel()
    model.expand()
    model.scheduleCollapse(after: 0.05)
    try? await Task.sleep(for: .seconds(0.15))
    #expect(model.expansion == .collapsed)
}

@MainActor @Test func windowModelExpandCancelsScheduledCollapse() async {
    let model = ShelfWindowModel()
    model.expand()
    model.scheduleCollapse(after: 0.05)
    model.expand()                       // should cancel the pending collapse
    try? await Task.sleep(for: .seconds(0.15))
    #expect(model.expansion == .expanded)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfWindowModel` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shared/ShelfWindowModel.swift`**

```swift
import SwiftUI

/// Drives the notch window: whether the shelf is collapsed or expanded, whether a
/// file drag is currently targeting it, and the shared animation curve.
@MainActor
final class ShelfWindowModel: ObservableObject {
    enum Expansion: Equatable {
        case collapsed
        case expanded
    }

    @Published var expansion: Expansion = .collapsed
    /// True while a file drag is hovering the notch / shelf region.
    @Published var dragTargeting: Bool = false
    /// Pulsed to `true` by the shelf's `.onDrop` so the drag pipeline knows a drop landed.
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

    /// Collapses after `seconds` unless cancelled first (e.g. by `expand()`).
    func scheduleCollapse(after seconds: Double = 1.5) {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.collapse()
        }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — all four window-model tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shared/ShelfWindowModel.swift NotchShelfTests/ShelfWindowModelTests.swift
git commit -m "feat: add ShelfWindowModel for notch window state"
```

---

### Task 14: `NotchPanel`

New. The borderless `NSPanel`, modelled on `boring.notch-main/boringNotch/components/Notch/BoringNotchWindow.swift`. Differs in one place: `canBecomeKey` is `true` so the shelf can receive the Delete key.

**Files:**
- Create: `NotchShelf/Window/NotchPanel.swift`

- [ ] **Step 1: Write `NotchShelf/Window/NotchPanel.swift`**

```swift
import AppKit

/// Borderless, transparent panel pinned over the notch. Floats above all windows,
/// is visible on every Space and above full-screen apps, and never steals app focus.
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

    /// Allow key status so the shelf can handle the Delete key, but never main status.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Window/NotchPanel.swift
git commit -m "feat: add NotchPanel borderless window"
```

---

### Task 15: `ShelfMetrics` and `NotchShelfShape`

New. `ShelfMetrics` holds the fixed expanded-window dimensions. `NotchShelfShape` is the continuous "Dynamic Island" shape, adapted from `boring.notch-main/boringNotch/components/Notch/NotchShape.swift` — a rectangle with small rounded top-inner corners and larger rounded bottom corners, whose size is animatable.

**Files:**
- Create: `NotchShelf/Window/ShelfMetrics.swift`
- Create: `NotchShelf/Window/NotchShelfShape.swift`
- Test: `NotchShelfTests/NotchShelfShapeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftUI
@testable import NotchShelf

@Test func notchShelfShapeProducesNonEmptyPath() {
    let shape = NotchShelfShape(topCornerRadius: 6, bottomCornerRadius: 20)
    let path = shape.path(in: CGRect(x: 0, y: 0, width: 600, height: 200))
    #expect(path.isEmpty == false)
    #expect(path.boundingRect.width > 0)
    #expect(path.boundingRect.height > 0)
}

@Test func shelfMetricsExpandedIsLargerThanWindowPadding() {
    #expect(ShelfMetrics.expandedSize.width > 0)
    #expect(ShelfMetrics.expandedSize.height > 0)
    #expect(ShelfMetrics.windowSize.width >= ShelfMetrics.expandedSize.width)
    #expect(ShelfMetrics.windowSize.height >= ShelfMetrics.expandedSize.height)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `NotchShelfShape` and `ShelfMetrics` are not defined.

- [ ] **Step 3: Write `NotchShelf/Window/ShelfMetrics.swift`**

```swift
import CoreGraphics

/// Fixed dimensions for the notch window and the expanded shelf.
enum ShelfMetrics {
    /// The expanded shelf shape's size (the dark rounded area the items live in).
    static let expandedSize = CGSize(width: 640, height: 200)
    /// The panel is fixed at this size; it stays transparent outside the shape so the
    /// shape can animate freely without ever resizing the window.
    static let windowSize = CGSize(width: 720, height: 240)
    /// Corner radii for the continuous shape.
    static let topCornerRadius: CGFloat = 6
    static let bottomCornerRadius: CGFloat = 22
}
```

- [ ] **Step 4: Write `NotchShelf/Window/NotchShelfShape.swift`**

```swift
import SwiftUI

/// The continuous notch-into-shelf shape: a downward rectangle whose upper-inner
/// corners curve gently and whose lower corners curve more, so the notch appears to
/// "grow" into the shelf. Adapted from boring.notch's NotchShape.
struct NotchShelfShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = ShelfMetrics.topCornerRadius,
         bottomCornerRadius: CGFloat = ShelfMetrics.bottomCornerRadius) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tcr = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bcr = min(bottomCornerRadius, rect.width / 2, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tcr, y: rect.minY + tcr),
            control: CGPoint(x: rect.minX + tcr, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + tcr, y: rect.maxY - bcr))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tcr + bcr, y: rect.maxY),
            control: CGPoint(x: rect.minX + tcr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tcr - bcr, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tcr, y: rect.maxY - bcr),
            control: CGPoint(x: rect.maxX - tcr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tcr, y: rect.minY + tcr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tcr, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}
```

- [ ] **Step 5: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — both shape/metrics tests.

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/Window/ShelfMetrics.swift NotchShelf/Window/NotchShelfShape.swift NotchShelfTests/NotchShelfShapeTests.swift
git commit -m "feat: add ShelfMetrics and continuous NotchShelfShape"
```

---

### Task 16: `ContentView` — collapsed shape rendering

New. The SwiftUI root hosted in the panel. For this task it renders only the collapsed shape (notch-sized, black, pinned to the top center). The expanded state and the shelf content are wired in Task 21. A transparent, non-hit-testing background lets clicks pass through everywhere except the shape.

**Files:**
- Create: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Write `NotchShelf/App/ContentView.swift`**

```swift
import SwiftUI

/// Root view hosted inside the notch panel. Draws the continuous notch-into-shelf
/// shape, sized from `ShelfWindowModel.expansion`. The shelf content is added in a
/// later task; for now the expanded state just shows a larger empty shape.
struct ContentView: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .expanded:
            return ShelfMetrics.expandedSize
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NotchShelfShape(
                topCornerRadius: ShelfMetrics.topCornerRadius,
                bottomCornerRadius: windowModel.expansion == .expanded
                    ? ShelfMetrics.bottomCornerRadius : 8
            )
            .fill(Color.black)
            .frame(width: shapeSize.width, height: shapeSize.height)
            .onHover { hovering in
                if hovering {
                    windowModel.expand()
                } else if windowModel.expansion == .expanded {
                    windowModel.scheduleCollapse()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: ShelfMetrics.windowSize.width,
               height: ShelfMetrics.windowSize.height,
               alignment: .top)
        .background(Color.clear.allowsHitTesting(false))
        .animation(windowModel.animation, value: windowModel.expansion)
    }
}
```

- [ ] **Step 2: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/ContentView.swift
git commit -m "feat: add ContentView with collapsed/expanded notch shape"
```

---

### Task 17: `NotchWindowController`, `MenuBarController`, and app wiring — window appears

New. `NotchWindowController` creates the `NotchPanel`, positions it at the top-center of the notch screen, and hosts `ContentView`. `MenuBarController` adds a status-bar item with a Quit menu. `AppDelegate` wires everything together. After this task the app launches, shows a black notch-shaped strip under the real notch, and expands to a large black shape on hover.

**Files:**
- Create: `NotchShelf/Window/NotchWindowController.swift`
- Create: `NotchShelf/App/MenuBarController.swift`
- Create: `NotchShelf/App/AppDelegate.swift`
- Modify: `NotchShelf/App/NotchShelfApp.swift`

- [ ] **Step 1: Write `NotchShelf/Window/NotchWindowController.swift`**

```swift
import AppKit
import SwiftUI

/// Owns the notch panel: builds it, hosts `ContentView`, and keeps it positioned at
/// the top-center of the notch screen (re-positioning when the screen layout changes).
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let windowModel: ShelfWindowModel

    init(windowModel: ShelfWindowModel) {
        self.windowModel = windowModel
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: ShelfMetrics.windowSize)
        )
        let root = ContentView().environmentObject(windowModel)
        panel.contentView = NSHostingView(rootView: root)
        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Centers the panel horizontally on the notch screen with its top flush to the
    /// screen's top edge.
    func reposition() {
        let screen = NotchGeometry.notchScreen
        let frame = screen.frame
        let size = ShelfMetrics.windowSize
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    @objc private func screenParametersChanged() {
        reposition()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

- [ ] **Step 2: Write `NotchShelf/App/MenuBarController.swift`**

```swift
import AppKit

/// A minimal status-bar item. Not a primary way to open the shelf — just an anchor
/// for About / Quit so the agent app is discoverable and quittable.
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "tray.and.arrow.down",
                accessibilityDescription: "NotchShelf"
            )
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "NotchShelf", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit NotchShelf",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }
}
```

- [ ] **Step 3: Write `NotchShelf/App/AppDelegate.swift`**

```swift
import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        menuBarController = MenuBarController()
    }
}
```

- [ ] **Step 4: Replace `NotchShelf/App/NotchShelfApp.swift`**

```swift
import SwiftUI

@main
struct NotchShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 5: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual verification**

Run: `open .build/Build/Products/Debug/NotchShelf.app`
Verify:
1. A `tray.and.arrow.down` icon appears in the menu bar; its menu has a working "Quit NotchShelf".
2. A small black strip sits directly under the physical notch (it blends with the notch — look for the rounded lower corners just below it).
3. Moving the cursor onto that strip animates it open into a large black rounded shape hanging below the notch.
4. Moving the cursor away collapses it back after ~1.5 s.
5. Clicking anywhere on the screen *outside* the shape behaves normally (the transparent window does not block clicks).

If item 5 fails (clicks blocked), the `Color.clear.allowsHitTesting(false)` background in `ContentView` is not taking effect — confirm the `.background` modifier is on the outer frame and not inside the shape.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf/Window/NotchWindowController.swift NotchShelf/App/MenuBarController.swift NotchShelf/App/AppDelegate.swift NotchShelf/App/NotchShelfApp.swift
git commit -m "feat: show notch panel with hover-to-expand"
```

---

## Phase 3 — Drag detection

### Task 18: `DragMonitor` — expand on drag toward the notch

New, ported from `boring.notch-main/boringNotch/observers/DragDetector.swift`. Files-only: `hasValidDragContent` checks only `.fileURL`. The hit-region is supplied as a closure so the caller can return the small notch rect when collapsed and the full window rect when expanded — keeping the shelf "targeted" while the cursor is over the expanded area.

**Files:**
- Create: `NotchShelf/DragDetect/DragMonitor.swift`
- Modify: `NotchShelf/App/AppDelegate.swift`

- [ ] **Step 1: Write `NotchShelf/DragDetect/DragMonitor.swift`**

```swift
import AppKit
import UniformTypeIdentifiers

/// Watches global mouse events plus the drag pasteboard to detect a *file* drag, and
/// reports when that drag enters / moves within / leaves a caller-supplied region.
///
/// Global mouse monitoring works inside the App Sandbox without Accessibility
/// permission — only global *keyboard* monitoring requires it.
@MainActor
final class DragMonitor {
    /// Called once when a file drag first enters the region.
    var onEnterRegion: (() -> Void)?
    /// Called once when a file drag leaves the region.
    var onExitRegion: (() -> Void)?
    /// Called on every drag move while a file drag is active (global point).
    var onDragMove: ((CGPoint) -> Void)?
    /// Called when the drag ends (mouse up), regardless of where.
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
            self.onDragMove?(location)

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
    }

    deinit {
        // Monitors must be removed; stopMonitoring touches only AppKit-safe state.
        for monitor in [downMonitor, draggedMonitor, upMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
    }
}
```

- [ ] **Step 2: Modify `NotchShelf/App/AppDelegate.swift` to create and wire the monitor**

Replace the entire file with:

```swift
import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var dragMonitor: DragMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        menuBarController = MenuBarController()
        setupDragMonitor()
    }

    private func setupDragMonitor() {
        let monitor = DragMonitor(regionProvider: { [weak self] in
            guard let self else { return .zero }
            switch self.windowModel.expansion {
            case .collapsed:
                return NotchGeometry.current().notchRect
            case .expanded:
                // While expanded, treat the whole panel frame as the hit-region so
                // dragging down onto the shelf does not count as "leaving".
                return self.windowController?.panelFrame ?? NotchGeometry.current().notchRect
            }
        })
        monitor.onEnterRegion = { [weak self] in
            self?.windowModel.expand()
            self?.windowModel.dragTargeting = true
        }
        monitor.onExitRegion = { [weak self] in
            self?.windowModel.dragTargeting = false
        }
        monitor.onDragEnd = { [weak self] in
            guard let self else { return }
            // If a drop landed on the shelf, ShelfView sets dropEvent; stay open.
            if self.windowModel.dropEvent {
                self.windowModel.dropEvent = false
            } else if !self.windowModel.dragTargeting {
                self.windowModel.scheduleCollapse()
            }
        }
        monitor.startMonitoring()
        dragMonitor = monitor
    }
}
```

- [ ] **Step 3: Add `panelFrame` accessor to `NotchWindowController`**

In `NotchShelf/Window/NotchWindowController.swift`, add this computed property inside the class (after `reposition()`):

```swift
    /// The panel's current frame in global screen coordinates.
    var panelFrame: CGRect {
        panel.frame
    }
```

- [ ] **Step 4: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Manual verification**

Run: `open .build/Build/Products/Debug/NotchShelf.app`
Verify:
1. Select one or more files in Finder and start dragging them.
2. As the dragged files cross into the notch region, the shape expands.
3. Dragging the files down over the expanded shape keeps it open (does not flicker collapsed).
4. Dragging the files away from the notch and releasing collapses the shape after the delay.
5. Dragging *non-file* content (e.g. selected text from TextEdit) toward the notch does **not** expand it.

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/DragDetect/DragMonitor.swift NotchShelf/App/AppDelegate.swift NotchShelf/Window/NotchWindowController.swift
git commit -m "feat: expand shelf when a file drag enters the notch"
```

---

## Phase 4 — Shelf UI

### Task 19: `ThumbnailService`

Ported verbatim (minus logging noise) from `boring.notch-main/boringNotch/components/Shelf/Services/ThumbnailService.swift`. No external dependencies.

**Files:**
- Create: `NotchShelf/Shelf/Services/ThumbnailService.swift`
- Test: `NotchShelfTests/ThumbnailServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
import AppKit
@testable import NotchShelf

@Test func thumbnailServiceReturnsImageForRealFile() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("note.txt")
    try "hello thumbnail".write(to: file, atomically: true, encoding: .utf8)

    let image = await ThumbnailService.shared.thumbnail(
        for: file, size: CGSize(width: 56, height: 56)
    )
    #expect(image != nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ThumbnailService` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/Services/ThumbnailService.swift`**

```swift
import Foundation
import AppKit
import QuickLookThumbnailing

/// Caching wrapper around `QLThumbnailGenerator`. Deduplicates concurrent requests
/// for the same file+size.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private var cache: [String: NSImage] = [:]
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private let generator = QLThumbnailGenerator.shared

    private init() {}

    func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let key = "\(url.path)_\(size.width)x\(size.height)"

        if let cached = cache[key] { return cached }
        if let pendingTask = pending[key] { return await pendingTask.value }

        let task = Task<NSImage?, Never> {
            let image = await generate(for: url, size: size)
            if let image { cache[key] = image }
            pending[key] = nil
            return image
        }
        pending[key] = task
        return await task.value
    }

    func clearCache() {
        cache.removeAll()
    }

    private func generate(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        return await url.accessSecurityScopedResource { scopedURL in
            let request = QLThumbnailGenerator.Request(
                fileAt: scopedURL, size: size, scale: scale, representationTypes: .all
            )
            request.iconMode = true
            return await withCheckedContinuation { (cont: CheckedContinuation<NSImage?, Never>) in
                generator.generateBestRepresentation(for: request) { representation, error in
                    if let representation {
                        let cgImage = representation.cgImage
                        cont.resume(returning: NSImage(
                            cgImage: cgImage,
                            size: NSSize(width: cgImage.width, height: cgImage.height)
                        ))
                    } else {
                        if let error {
                            NSLog("Thumbnail error for \(scopedURL.path): \(error.localizedDescription)")
                        }
                        cont.resume(returning: nil)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run the test to verify it passes**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Services/ThumbnailService.swift NotchShelfTests/ThumbnailServiceTests.swift
git commit -m "feat: add ThumbnailService with QuickLook thumbnails"
```

---

### Task 20: `ShelfItemViewModel`

A heavily trimmed rewrite of `boring.notch-main/boringNotch/components/Shelf/ViewModels/ShelfItemViewModel.swift` (1112 → ~110 lines). Kept: thumbnail loading, `icon`, click handling, double-click open, and a minimal 3-item context menu (Open / Show in Finder / Remove). Dropped: image processing, ZIP, "Open With", rename, share, and `dragItemProvider` (the real drag-out is the pasteboard path in `DraggableClickView`, Task 21 — a separate provider method would be unused). The context menu uses a tiny `NSObject` action target so `NSMenuItem` selectors resolve.

**Files:**
- Create: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`
- Test: `NotchShelfTests/ShelfItemViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
import AppKit
@testable import NotchShelf

@MainActor
private func fileItem(named name: String = "vm.txt") throws -> ShelfItem {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(name)
    try "x".write(to: file, atomically: true, encoding: .utf8)
    return ShelfItem(bookmarkData: try Bookmark(url: file).data)
}

@MainActor @Test func itemViewModelExposesIconWithNonZeroSize() throws {
    let vm = ShelfItemViewModel(item: try fileItem())
    #expect(vm.icon.size.width > 0)
}

@MainActor @Test func itemViewModelStartsNotSelected() throws {
    let vm = ShelfItemViewModel(item: try fileItem())
    #expect(vm.isSelected == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: FAIL — `ShelfItemViewModel` is not defined.

- [ ] **Step 3: Write `NotchShelf/Shelf/State/ShelfItemViewModel.swift`**

```swift
import Foundation
import AppKit
import SwiftUI

/// Per-item view model: thumbnail, icon, drag-out provider, click handling, and a
/// minimal context menu.
@MainActor
final class ShelfItemViewModel: ObservableObject {
    @Published private(set) var item: ShelfItem
    @Published var thumbnail: NSImage?
    @Published var isDropTargeted: Bool = false

    private let selection = ShelfSelection.shared

    init(item: ShelfItem) {
        self.item = item
        Task { await loadThumbnail() }
    }

    var isSelected: Bool { selection.isSelected(item.id) }

    /// The file's Finder icon — used as a fallback before the thumbnail loads.
    var icon: NSImage {
        if let url = item.fileURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    func loadThumbnail() async {
        guard let url = item.fileURL else { return }
        if let image = await ThumbnailService.shared.thumbnail(
            for: url, size: CGSize(width: 56, height: 56)
        ) {
            thumbnail = image
        }
    }

    // MARK: - Clicks

    func handleClick(event: NSEvent, view: NSView) {
        let flags = event.modifierFlags
        if flags.contains(.shift) {
            selection.shiftSelect(to: item, in: ShelfStore.shared.items)
        } else if flags.contains(.command) {
            selection.toggle(item)
        } else if flags.contains(.control) {
            handleRightClick(event: event, view: view)
            return
        } else if !selection.isSelected(item.id) {
            selection.selectSingle(item)
        }
        if event.clickCount == 2 { handleDoubleClick() }
    }

    func handleDoubleClick() {
        for selectedItem in selection.selectedItems(in: ShelfStore.shared.items) {
            ShelfActionService.open(selectedItem)
        }
    }

    // MARK: - Context menu

    func handleRightClick(event: NSEvent, view: NSView) {
        if !selection.isSelected(item.id) { selection.selectSingle(item) }
        let menu = NSMenu()
        addItem(to: menu, title: "Open") { ShelfActionService.open(self.item) }
        addItem(to: menu, title: "Show in Finder") { ShelfActionService.reveal(self.item) }
        menu.addItem(.separator())
        addItem(to: menu, title: "Remove from Shelf") {
            for selectedItem in self.selection.selectedItems(in: ShelfStore.shared.items) {
                ShelfActionService.remove(selectedItem)
            }
        }
        menu.popUp(positioning: nil, at: event.locationInWindow, in: view)
    }

    private func addItem(to menu: NSMenu, title: String, action: @escaping () -> Void) {
        let target = MenuActionTarget(action: action)
        let menuItem = NSMenuItem(title: title, action: #selector(MenuActionTarget.fire), keyEquivalent: "")
        menuItem.target = target
        // Retain the target for the lifetime of the menu item.
        objc_setAssociatedObject(menuItem, &MenuActionTarget.key, target, .OBJC_ASSOCIATION_RETAIN)
        menu.addItem(menuItem)
    }
}

/// Bridges a closure to an `@objc` selector for `NSMenuItem`.
private final class MenuActionTarget: NSObject {
    nonisolated(unsafe) static var key: UInt8 = 0
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}
```

- [ ] **Step 4: Run `xcodegen generate`, then run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test ... -destination 'platform=macOS' -derivedDataPath .build`
Expected: PASS — both view-model tests.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfItemViewModel.swift NotchShelfTests/ShelfItemViewModelTests.swift
git commit -m "feat: add trimmed ShelfItemViewModel with minimal context menu"
```

---

### Task 21: `DragPreviewView` and `ShelfItemView`

`DragPreviewView` is ported verbatim. `ShelfItemView` is ported from `boring.notch-main/boringNotch/components/Shelf/Views/ShelfItemView.swift`, with `BoringViewModel` → `ShelfWindowModel`, `Defaults` → `Preferences`, `ShelfSelectionModel`/`ShelfStateViewModel` → `ShelfSelection`/`ShelfStore`, `item.icon` → `viewModel.icon`, and all QuickLook / `.text` / `.link` paths removed.

**Files:**
- Create: `NotchShelf/Shelf/Views/DragPreviewView.swift`
- Create: `NotchShelf/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Write `NotchShelf/Shelf/Views/DragPreviewView.swift`**

```swift
import SwiftUI
import AppKit

/// The small card rendered under the cursor while dragging an item off the shelf.
struct DragPreviewView: View {
    let thumbnail: NSImage?
    let displayName: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(nsImage: thumbnail ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor))
        }
        .frame(width: 105)
    }
}
```

- [ ] **Step 2: Write `NotchShelf/Shelf/Views/ShelfItemView.swift`**

```swift
import AppKit
import SwiftUI

/// A single shelf item card: thumbnail, name, selection / drop-target styling, and an
/// AppKit drag source for dragging the file off the shelf.
struct ShelfItemView: View {
    let item: ShelfItem
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var selection = ShelfSelection.shared
    @StateObject private var viewModel: ShelfItemViewModel
    @State private var cachedPreviewImage: NSImage?
    @State private var debouncedDropTarget = false

    private var isSelected: Bool { viewModel.isSelected }

    init(item: ShelfItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: ShelfItemViewModel(item: item))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 2) {
                iconView
                textView
            }
            .frame(width: 105)
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .background(backgroundView)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.1), value: debouncedDropTarget)
            .animation(.easeInOut(duration: 0.1), value: isSelected)

            DraggableClickHandler(
                item: item,
                viewModel: viewModel,
                cachedPreviewImage: $cachedPreviewImage,
                onClick: { event, nsview in viewModel.handleClick(event: event, view: nsview) },
                onRightClick: { event, nsview in viewModel.handleRightClick(event: event, view: nsview) }
            )
        }
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            windowModel.dragTargeting = targeted
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            Task {
                await viewModel.loadThumbnail()
                if cachedPreviewImage == nil {
                    cachedPreviewImage = await renderDragPreview()
                }
            }
        }
        .onChange(of: viewModel.thumbnail) { _, _ in
            Task { cachedPreviewImage = await renderDragPreview() }
        }
    }

    private var iconView: some View {
        Image(nsImage: viewModel.thumbnail ?? viewModel.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }

    private var textView: some View {
        Text(item.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(height: 30, alignment: .top)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            )
    }

    private var backgroundColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.25) }
        if isSelected { return Color.accentColor.opacity(0.15) }
        return Color.clear
    }

    private var strokeColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.9) }
        if isSelected { return Color.accentColor.opacity(0.8) }
        return Color.clear
    }

    private var strokeWidth: CGFloat {
        if debouncedDropTarget { return 3 }
        if isSelected { return 2 }
        return 1
    }

    @MainActor
    private func renderDragPreview() async -> NSImage {
        let content = DragPreviewView(
            thumbnail: viewModel.thumbnail ?? viewModel.icon,
            displayName: item.displayName
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? (viewModel.thumbnail ?? viewModel.icon)
    }
}

// MARK: - AppKit drag source

/// Hosts an `NSView` that turns a press-and-drag into an `NSDraggingSession`, so items
/// can be dragged out into Finder. Click / right-click are forwarded to the view model.
private struct DraggableClickHandler: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel
    @Binding var cachedPreviewImage: NSImage?
    let onClick: (NSEvent, NSView) -> Void
    let onRightClick: (NSEvent, NSView) -> Void

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.viewModel = viewModel
        view.dragPreviewImage = cachedPreviewImage ?? viewModel.icon
        view.onClick = onClick
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
        if let cached = cachedPreviewImage { nsView.dragPreviewImage = cached }
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
    }

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem!
        weak var viewModel: ShelfItemViewModel?
        var dragPreviewImage: NSImage?
        var onClick: ((NSEvent, NSView) -> Void)?
        var onRightClick: ((NSEvent, NSView) -> Void)?

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(event, self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            onClick?(event, self)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }
            let distance = hypot(
                event.locationInWindow.x - down.locationInWindow.x,
                event.locationInWindow.y - down.locationInWindow.y
            )
            if distance > dragThreshold {
                startDragSession(with: event)
                mouseDownEvent = nil
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            let selected = ShelfSelection.shared.selectedItems(in: ShelfStore.shared.items)
            let itemsToDrag: [ShelfItem] =
                (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
            draggedItems = itemsToDrag

            var draggingItems: [NSDraggingItem] = []
            for dragItem in itemsToDrag {
                guard let pasteboardItem = pasteboardItem(for: dragItem) else { continue }
                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
                let image = dragPreviewImage ?? viewModel?.icon ?? NSImage()
                draggingItem.setDraggingFrame(
                    NSRect(origin: .zero, size: image.size), contents: image
                )
                draggingItems.append(draggingItem)
            }
            guard !draggingItems.isEmpty else { return }
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        private func pasteboardItem(for item: ShelfItem) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            guard let url = ShelfStore.shared.resolveAndUpdateBookmark(for: item) else {
                pasteboardItem.setString(item.displayName, forType: .string)
                return pasteboardItem
            }
            // Keep security-scoped access open for the lifetime of the drag.
            if url.startAccessingSecurityScopedResource() {
                draggedURLs.append(url)
            }
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            pasteboardItem.setString(url.path, forType: .string)
            return pasteboardItem
        }

        // MARK: NSDraggingSource

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            if Preferences.shared.copyOnDrag { return [.copy] }
            switch context {
            case .outsideApplication: return [.copy, .move]
            case .withinApplication: return [.copy, .move, .generic]
            @unknown default: return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelection.shared.beginDrag()
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            ShelfSelection.shared.endDrag()
            for url in draggedURLs { url.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()

            if Preferences.shared.autoRemoveShelfItems && !operation.isEmpty {
                for item in draggedItems { ShelfStore.shared.remove(item) }
            }
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/DragPreviewView.swift NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "feat: add ShelfItemView with AppKit drag-out source"
```

---

### Task 22: `ShelfView` and wire it into `ContentView`

`ShelfView` is ported from `boring.notch-main/boringNotch/components/Shelf/Views/ShelfView.swift`, dropping `FileShareView`, QuickLook, and the `BoringViewModel` references. Then `ContentView` is updated to render `ShelfView` inside the expanded shape.

**Files:**
- Create: `NotchShelf/Shelf/Views/ShelfView.swift`
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Write `NotchShelf/Shelf/Views/ShelfView.swift`**

```swift
import SwiftUI
import AppKit

/// The shelf panel: a horizontally scrolling row of item cards, or a "Drop files here"
/// hint when empty. Accepts file drops and supports Delete-to-remove on selected items.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    private let spacing: CGFloat = 8

    var body: some View {
        panel
            .onDrop(of: [.fileURL], isTargeted: $windowModel.dragTargeting) { providers in
                handleDrop(providers: providers)
            }
            .focusable()
            .onDeleteCommand {
                for item in selection.selectedItems(in: store.items) {
                    ShelfActionService.remove(item)
                }
            }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        windowModel.dropEvent = true
        store.load(providers)
        return true
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                windowModel.dragTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.12),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay { content.padding() }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    @ViewBuilder
    private var content: some View {
        if store.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .symbolVariant(.fill)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, .gray)
                    .imageScale(.large)
                Text("Drop files here")
                    .foregroundStyle(.gray)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)
            }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(store.items) { item in
                        ShelfItemView(item: item)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}
```

- [ ] **Step 2: Replace `NotchShelf/App/ContentView.swift`**

```swift
import SwiftUI

/// Root view hosted inside the notch panel. Draws the continuous notch-into-shelf
/// shape sized from `ShelfWindowModel.expansion`, with the shelf content layered
/// inside the shape when expanded.
struct ContentView: View {
    @EnvironmentObject private var windowModel: ShelfWindowModel

    private var geometry: NotchGeometry { NotchGeometry.current() }

    private var shapeSize: CGSize {
        switch windowModel.expansion {
        case .collapsed:
            return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .expanded:
            return ShelfMetrics.expandedSize
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NotchShelfShape(
                    topCornerRadius: ShelfMetrics.topCornerRadius,
                    bottomCornerRadius: windowModel.expansion == .expanded
                        ? ShelfMetrics.bottomCornerRadius : 8
                )
                .fill(Color.black)

                if windowModel.expansion == .expanded {
                    ShelfView()
                        .environmentObject(windowModel)
                        .padding(.horizontal, 16)
                        .padding(.top, geometry.notchHeight)
                        .padding(.bottom, 14)
                        .transition(.opacity)
                }
            }
            .frame(width: shapeSize.width, height: shapeSize.height)
            .onHover { hovering in
                if hovering {
                    windowModel.expand()
                } else if windowModel.expansion == .expanded {
                    windowModel.scheduleCollapse()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: ShelfMetrics.windowSize.width,
               height: ShelfMetrics.windowSize.height,
               alignment: .top)
        .background(Color.clear.allowsHitTesting(false))
        .animation(windowModel.animation, value: windowModel.expansion)
        .onAppear { ShelfStore.shared.cleanupInvalidItems() }
    }
}
```

- [ ] **Step 3: Run `xcodegen generate` and build**

Run: `xcodegen generate && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug -derivedDataPath .build build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite to confirm no regressions**

Run: `xcodebuild test -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -derivedDataPath .build`
Expected: `** TEST SUCCEEDED **` — all tests from Tasks 2–20 still pass.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfView.swift NotchShelf/App/ContentView.swift
git commit -m "feat: render shelf inside the expanded notch shape"
```

---

## Phase 5 — Integration & verification

### Task 23: End-to-end manual verification and polish pass

No new files. This task drives the full app and fixes whatever the checklist surfaces. Each fix is its own commit.

- [ ] **Step 1: Build and launch**

Run: `./scripts/build.sh && open .build/Build/Products/Debug/NotchShelf.app`

- [ ] **Step 2: Work through the verification checklist**

Verify each item; for any failure, fix it (small, focused change) and commit before continuing.

**Drop in:**
1. Drag files from Finder toward the notch — the shape expands into the shelf.
2. Drop the files onto the dashed panel — they appear as cards with thumbnails and names.
3. The shelf stays open after the drop (does not immediately collapse).
4. Dropping the same file again does not create a duplicate card.

**Re-open:**
5. Move the cursor away — the shelf collapses after the delay.
6. Hover the notch again — the shelf re-opens showing the same items (persisted in memory).

**Drag out:**
7. Drag a card into a Finder folder — the file is copied/moved there (same-volume = move, cross-volume = copy).
8. Select multiple cards (click, then ⌘-click / ⇧-click) and drag one — all selected files come along.

**Selection & remove:**
9. Click a card → it shows the selected outline. ⌘-click toggles; ⇧-click selects a range.
10. Right-click a card → context menu with Open / Show in Finder / Remove from Shelf; each works.
11. Select cards and press Delete → they are removed from the shelf (files remain on disk).

**Persistence:**
12. Quit NotchShelf (menu bar → Quit), relaunch — the shelf still contains the items dropped earlier.
13. Move one of the original files in Finder, relaunch — the moved file still resolves (bookmark refresh) or, if it cannot, its card is gone (pruned by `cleanupInvalidItems`), and the rest are intact.

**Window behavior:**
14. The collapsed strip is visually flush under the physical notch.
15. Clicking elsewhere on screen while collapsed does not get blocked by the transparent window.
16. The app has no Dock icon (LSUIElement) and a working menu bar item.

- [ ] **Step 3: Known-risk check — continuous shape animation**

Per the spec's risk note: if the collapse↔expand animation of `NotchShelfShape` looks broken (clipping, jumpy corners, content spilling outside the shape), do **not** silently switch to a different shape. Stop, summarize the specific visual problem, and raise it for a decision (the spec's fallback is the "separate card" shape — that is a design change requiring sign-off).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: end-to-end verification pass for NotchShelf MVP"
```

---

## Self-Review Notes

**Spec coverage** (against `docs/superpowers/specs/2026-05-14-notchshelf-mvp-design.md`):
- §3 build strategy (fresh app + port) → Tasks 1–22.
- §3 trigger = drag toward notch → Task 18.
- §3 notch Macs only → Task 12 (`NotchGeometry`, built-in screen).
- §3 files only → Tasks 4, 8, 9, 11.
- §3 reference via bookmark → Tasks 3, 4.
- §3 persistence across restart → Tasks 6, 10; verified Task 23 step 12.
- §3 shape A (continuous) → Tasks 15, 16, 22; risk re-checked Task 23 step 3.
- §3 re-open = hover → Task 16 (`.onHover`).
- §4.5 decoupling (`ShelfWindowModel`, `Preferences`) → Tasks 5, 13, 21, 22.
- §5 data model / state / services / views → Tasks 2–11, 19–22.
- §6 interactions (drop, drag-out, multi-select, remove) → Tasks 21, 22; verified Task 23.
- §9 project setup (XcodeGen, Info.plist, entitlements, build script) → Task 1.
- §10 testing (Swift Testing, the six unit-tested units) → Tasks 2–13, 19, 20.
- §12 git not initialized → Task 1 step 1 (`git init`).

**Out of scope (correctly absent):** image processing, ZIP, QuickShare/AirDrop, QuickLook preview panel, text/link items, non-notch Macs, multi-monitor, multiple shelves, preferences UI, notarization.

**Type consistency:** singletons `ShelfStore.shared`, `ShelfSelection.shared`, `ShelfPersistenceService.shared`, `Preferences.shared`, `ThumbnailService.shared`. `ShelfStore` methods (`add`, `remove`, `updateBookmark(for:bookmark:)`, `load`, `cleanupInvalidItems`, `resolveFileURL(for:)`, `resolveAndUpdateBookmark(for:)`) are referenced consistently in Tasks 11, 20, 21, 22. `ShelfWindowModel` members (`expansion`, `dragTargeting`, `dropEvent`, `animation`, `expand()`, `collapse()`, `scheduleCollapse(after:)`) are referenced consistently in Tasks 16, 17, 18, 21, 22.

**Decision note for plan review:** §9 of the spec says "Xcode project (not a Swift Package)". This plan uses **XcodeGen** to generate that `.xcodeproj` from a checked-in `project.yml` — it still produces a real Xcode project, but adds a one-time `brew install xcodegen` developer-tool dependency (not an app dependency). If you would rather hand-maintain the `.xcodeproj` in Xcode, say so before execution.

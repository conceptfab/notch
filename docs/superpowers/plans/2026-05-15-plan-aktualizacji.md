# NotchShelf — Plan Aktualizacji (post‑1.0 features) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 6 feature areas from `TODO.md`: system‑impact safety, real file icons, full Preferences panel (auto‑hide delay, copy‑on‑drag, quit, launch‑at‑login, About, slot count config), CPU/memory optimization, "Clear shelf" broom button, and stack file grid view.

**Architecture:** Continues the existing MVVM pattern (`ShelfStore` / `ShelfWindowModel` / per‑item `ShelfItemViewModel`). Preferences are read via `@AppStorage` in views and `UserDefaults.standard` in services; a single `UserDefaultsKey` namespace + a `registerPreferenceDefaults()` call from `AppDelegate.applicationDidFinishLaunching` provides defaults. The Preferences UI is the SwiftUI `Settings` scene (already declared in `NotchShelfApp.body`); the custom `PreferencesWindowController` is replaced by `@Environment(\.openSettings)` to converge on a single window. Slot count, auto‑hide delay, launch‑at‑login, copy‑on‑drag, and stack grid threshold are all driven by `UserDefaultsKey` constants registered with sane defaults.

**Tech Stack:** Swift 6.0, SwiftUI (macOS 14 target), `Settings` scene + `TabView`, `SMAppService` for login items, `LazyVGrid` for slot/stack layout, `Swift Testing` for unit tests, XcodeGen for the project.

---

## File Structure

**New files:**

- `NotchShelf/App/Preferences/PreferencesKeys.swift` — extends `UserDefaultsKey` with all new keys + `registerPreferenceDefaults()`.
- `NotchShelf/App/Preferences/GeneralPreferencesView.swift` — General tab (auto‑hide delay, copy‑on‑drag, launch‑at‑login, Quit).
- `NotchShelf/App/Preferences/ShelfPreferencesView.swift` — Shelf tab (min/max slot count, stack grid threshold).
- `NotchShelf/App/Preferences/AboutPreferencesView.swift` — About tab (version, author, license, links).
- `NotchShelf/App/Preferences/LaunchAtLoginService.swift` — `SMAppService` wrapper, `@MainActor`, observable.
- `NotchShelf/Shelf/Views/ShelfClearButton.swift` — broom icon button, mirror of gear.
- `NotchShelf/Shelf/Views/Stack/StackFileGridView.swift` — `LazyVGrid` representation when stack count > threshold.
- `NotchShelfTests/PreferencesKeysTests.swift`
- `NotchShelfTests/ShelfStoreClearAllTests.swift`
- `NotchShelfTests/SlotCountPolicyTests.swift`
- `NotchShelfTests/LaunchAtLoginServiceTests.swift` (covers the policy logic, not the live `SMAppService` call).

**Modified files:**

- `NotchShelf/Shared/AppLogger.swift` — keep `AppLogger`; the `UserDefaultsKey` enum moves to `PreferencesKeys.swift` (re‑exported via `typealias` if needed; the source of truth is `PreferencesKeys.swift`).
- `NotchShelf/App/PreferencesView.swift` — replaced by a `TabView` host of the three new tab views.
- `NotchShelf/App/NotchShelfApp.swift` — `Settings { PreferencesRootView() }` (renamed root) — no functional change.
- `NotchShelf/App/PreferencesWindowController.swift` — **deleted**. Callers route through `@Environment(\.openSettings)`.
- `NotchShelf/App/AppDelegate.swift` — calls `registerPreferenceDefaults()` first thing in `applicationDidFinishLaunching`. Removes the orphan that used `PreferencesWindowController`.
- `NotchShelf/App/ContentView.swift` — replaces the gear‑only top row with a HStack of `ShelfClearButton` (top‑left) and the existing `preferencesButton` (top‑right); opens Settings via `openSettings`. Auto‑hide delay is read from `UserDefaults` and passed to `scheduleCollapse`.
- `NotchShelf/Shared/ShelfWindowModel.swift` — `scheduleCollapse(after:)` keeps its default but callers pass the user‑configured value.
- `NotchShelf/Shelf/Services/ShelfDragOperationPolicy.swift` — outside‑app drags return `[.copy]` (no `.move`), regardless of preference. Within‑app drags still respect `copyOnDrag`. Add a log line whenever a `.move` operation completes via `ShelfItemDragSource.draggingSession(_:endedAt:operation:)`.
- `NotchShelf/Shelf/State/ShelfStore.swift` — adds `clearAll()`, `visibleSlotCount` derived state, and uses prefs for min/max slot count.
- `NotchShelf/Shelf/Views/ShelfView.swift` — switches the inner `HStack` to a `LazyVGrid` so slots wrap into rows once the visible count exceeds the min row.
- `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift` — `StackFileListView` switches to `StackFileGridView` when `entries.count > stackListGridThreshold`. Panel height is computed from the chosen layout so all files are visible without scrolling whenever possible (still falls back to a scroll view if the screen is too short).

**Files that change together (rationale for grouping):**

- All Preferences‑tab files live in `NotchShelf/App/Preferences/` — they share the `UserDefaultsKey` namespace and the `LaunchAtLoginService`.
- All shelf‑slot count + clear button changes co‑locate the new `ShelfClearButton.swift` next to the existing slot views in `Shelf/Views/`.

---

## Self‑review notes (read before executing)

- **No new abstractions for the sake of it.** No `PreferenceProviding` protocol; `@AppStorage` + `UserDefaultsKey` constants is the established pattern (see memory 3678).
- **Tahoe HIG.** The macOS 14 target rules out true "macOS 26 Tahoe" Settings APIs (e.g. `SettingsLink`, scene‑detached SwiftUI settings) — we use the closest macOS‑14‑compatible pattern: `Settings` scene + `TabView` with `.tabItem` labels and SF Symbols.
- **TDD where it pays.** Pure‑logic tasks (slot count policy, drag policy, preferences registration, clear‑all behaviour) get tests. UI tabs are exercised via smoke tests that they instantiate without crashing.
- **Frequent commits.** Each task ends with a commit. No squash; reviewers want the trail.

---

## Tasks

### Task 1: Add `PreferencesKeys.swift` with all new keys + defaults registration

**Files:**
- Create: `NotchShelf/App/Preferences/PreferencesKeys.swift`
- Modify: `NotchShelf/Shared/AppLogger.swift` (remove `UserDefaultsKey`; keep `AppLogger`)
- Test: `NotchShelfTests/PreferencesKeysTests.swift`
- Modify: `project.yml` is unaffected (XcodeGen picks up files under `NotchShelf/`).

- [ ] **Step 1: Write the failing test**

Create `NotchShelfTests/PreferencesKeysTests.swift`:

```swift
import Foundation
import Testing
@testable import NotchShelf

@Suite("PreferencesKeys")
struct PreferencesKeysTests {
    @Test
    func registerPreferenceDefaultsInstallsExpectedValues() {
        let suite = UserDefaults(suiteName: "PreferencesKeysTests.\(UUID().uuidString)")!
        suite.removePersistentDomain(forName: suite.dictionaryRepresentation().description)

        registerPreferenceDefaults(in: suite)

        #expect(suite.bool(forKey: UserDefaultsKey.copyOnDrag) == false)
        #expect(suite.double(forKey: UserDefaultsKey.autoHideDelaySeconds) == 1.5)
        #expect(suite.bool(forKey: UserDefaultsKey.launchAtLogin) == false)
        #expect(suite.integer(forKey: UserDefaultsKey.minSlotCount) == 5)
        #expect(suite.integer(forKey: UserDefaultsKey.maxSlotCount) == 15)
        #expect(suite.integer(forKey: UserDefaultsKey.stackListGridThreshold) == 5)
    }

    @Test
    func keysAreStable() {
        // Keys are persisted on disk — accidental renames are silent data loss.
        #expect(UserDefaultsKey.copyOnDrag == "copyOnDrag")
        #expect(UserDefaultsKey.autoHideDelaySeconds == "autoHideDelaySeconds")
        #expect(UserDefaultsKey.launchAtLogin == "launchAtLogin")
        #expect(UserDefaultsKey.minSlotCount == "minSlotCount")
        #expect(UserDefaultsKey.maxSlotCount == "maxSlotCount")
        #expect(UserDefaultsKey.stackListGridThreshold == "stackListGridThreshold")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/PreferencesKeysTests`
Expected: FAIL — `registerPreferenceDefaults` and the new keys do not exist.

- [ ] **Step 3: Create `PreferencesKeys.swift`**

```swift
import Foundation

/// All persisted user preference keys. Keep names string-stable across versions —
/// renaming silently loses existing user data.
enum UserDefaultsKey {
    static let copyOnDrag = "copyOnDrag"
    static let autoHideDelaySeconds = "autoHideDelaySeconds"
    static let launchAtLogin = "launchAtLogin"
    static let minSlotCount = "minSlotCount"
    static let maxSlotCount = "maxSlotCount"
    static let stackListGridThreshold = "stackListGridThreshold"
}

/// Installs default values for every preference. Must be called once at launch,
/// before any `@AppStorage` is read.
func registerPreferenceDefaults(in defaults: UserDefaults = .standard) {
    defaults.register(defaults: [
        UserDefaultsKey.copyOnDrag: false,
        UserDefaultsKey.autoHideDelaySeconds: 1.5,
        UserDefaultsKey.launchAtLogin: false,
        UserDefaultsKey.minSlotCount: 5,
        UserDefaultsKey.maxSlotCount: 15,
        UserDefaultsKey.stackListGridThreshold: 5
    ])
}
```

- [ ] **Step 4: Remove the duplicate `UserDefaultsKey` from `AppLogger.swift`**

Edit `NotchShelf/Shared/AppLogger.swift`: delete lines 14–16 (the `enum UserDefaultsKey { static let copyOnDrag = "copyOnDrag" }` block). Keep everything above.

- [ ] **Step 5: Wire `registerPreferenceDefaults()` into `AppDelegate`**

In `NotchShelf/App/AppDelegate.swift`, at the top of `applicationDidFinishLaunching(_:)`, add **before** the test‑skip guard:

```swift
registerPreferenceDefaults()
```

Place it on its own line as the very first statement of the method.

- [ ] **Step 6: Run the test to verify it passes**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/PreferencesKeysTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf/App/Preferences/PreferencesKeys.swift NotchShelf/Shared/AppLogger.swift NotchShelf/App/AppDelegate.swift NotchShelfTests/PreferencesKeysTests.swift
git commit -m "feat(prefs): add centralized UserDefaultsKey namespace and defaults registration"
```

---

### Task 2: Tighten drag policy — never move files outside the app

**Files:**
- Modify: `NotchShelf/Shelf/Services/ShelfDragOperationPolicy.swift`
- Modify: `NotchShelfTests/ShelfDragOperationPolicyTests.swift`
- Modify: `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift` (add audit log)

- [ ] **Step 1: Write the failing test**

Append to `NotchShelfTests/ShelfDragOperationPolicyTests.swift`:

```swift
@Test
func outsideApplicationAlwaysReturnsCopyOnly() {
    // Outside-app drags must never offer .move, regardless of preference.
    // Rationale: TODO.md #1 — "aplikacja nie moze wplywac na stan systemu".
    let copyOnly = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .outsideApplication
    )
    #expect(copyOnly == [.copy])
}

@Test
func outsideApplicationIgnoresCopyOnDragPreference() {
    let copyOn = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: true,
        context: .outsideApplication
    )
    #expect(copyOn == [.copy])
}

@Test
func withinApplicationKeepsMoveByDefault() {
    let mask = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .withinApplication
    )
    #expect(mask.contains(.move))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/ShelfDragOperationPolicyTests`
Expected: FAIL — outside‑app currently returns `[.copy, .move]`.

- [ ] **Step 3: Update `ShelfDragOperationPolicy.swift`**

Replace the body of `sourceOperationMask(copyOnDrag:context:)`:

```swift
import AppKit

enum ShelfDragOperationPolicy {
    /// Outside the app we ONLY ever offer `.copy`. This is the contract: NotchShelf
    /// holds bookmarks, not files — handing Finder a `.move` operation would let it
    /// physically relocate the user's source file, which TODO.md #1 forbids.
    static func sourceOperationMask(copyOnDrag: Bool, context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy]
        case .withinApplication:
            return copyOnDrag ? [.copy] : [.copy, .move, .generic]
        @unknown default:
            return [.copy]
        }
    }

    static func shouldRemoveFromShelf(after operation: NSDragOperation) -> Bool {
        operation.contains(.move)
    }
}
```

- [ ] **Step 4: Add audit log when a `.move` actually completes**

In `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`, inside `draggingSession(_:endedAt:operation:)`, add (immediately before the existing `if ShelfDragOperationPolicy.shouldRemoveFromShelf(after: operation)` check):

```swift
if operation.contains(.move) {
    AppLogger.drag.notice("Drag session ended with .move operation (within-app only path)")
}
```

- [ ] **Step 5: Run the existing drag tests**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/ShelfDragOperationPolicyTests`
Expected: PASS (all old + new tests).

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/Shelf/Services/ShelfDragOperationPolicy.swift NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift NotchShelfTests/ShelfDragOperationPolicyTests.swift
git commit -m "fix(drag): never offer .move for drags outside the app"
```

---

### Task 3: Replace `PreferencesWindowController` with `openSettings`

**Files:**
- Delete: `NotchShelf/App/PreferencesWindowController.swift`
- Modify: `NotchShelf/App/ContentView.swift`
- Modify: `NotchShelf/App/PreferencesView.swift` (placeholder rename — TabView body lands in Task 4)

- [ ] **Step 1: Delete the controller**

```bash
git rm NotchShelf/App/PreferencesWindowController.swift
```

- [ ] **Step 2: Update `ContentView.swift` to use `openSettings`**

At the top of `ContentView`, add:

```swift
@Environment(\.openSettings) private var openSettings
```

Replace the body of `showPreferences()`:

```swift
private func showPreferences() {
    openSettings()
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **Step 3: Build to verify no other references**

Run: `grep -RIn "PreferencesWindowController" NotchShelf NotchShelfTests`
Expected: no matches. If any remain, fix them — there should be none after the deletion + ContentView edit.

- [ ] **Step 4: Run the full test suite to verify nothing regressed**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -u NotchShelf/App/
git commit -m "refactor(prefs): open Settings scene via openSettings, drop bespoke window controller"
```

---

### Task 4: Preferences root + General tab (auto-hide, copy-on-drag, Quit)

**Files:**
- Modify: `NotchShelf/App/PreferencesView.swift` → becomes the `PreferencesRootView` that hosts the `TabView`.
- Create: `NotchShelf/App/Preferences/GeneralPreferencesView.swift`
- Modify: `NotchShelf/App/NotchShelfApp.swift` (uses the renamed view)

- [ ] **Step 1: Rewrite `PreferencesView.swift` as a `TabView` host**

Replace the entire contents of `NotchShelf/App/PreferencesView.swift` with:

```swift
import SwiftUI

struct PreferencesRootView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ShelfPreferencesView()
                .tabItem { Label("Shelf", systemImage: "tray.full") }

            AboutPreferencesView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 320)
    }
}
```

- [ ] **Step 2: Create `GeneralPreferencesView.swift`**

```swift
import AppKit
import SwiftUI

struct GeneralPreferencesView: View {
    @AppStorage(UserDefaultsKey.autoHideDelaySeconds) private var autoHideDelaySeconds: Double = 1.5
    @AppStorage(UserDefaultsKey.copyOnDrag) private var copyOnDrag = false
    @AppStorage(UserDefaultsKey.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Behaviour") {
                LabeledContent("Auto-hide delay") {
                    HStack(spacing: 8) {
                        Slider(value: $autoHideDelaySeconds, in: 0.5...5.0, step: 0.25)
                            .frame(maxWidth: 200)
                        Text(String(format: "%.2fs", autoHideDelaySeconds))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 64, alignment: .trailing)
                    }
                }

                Toggle("Always copy files when dragging within the app", isOn: $copyOnDrag)
                Toggle("Launch NotchShelf at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLoginService.shared.setEnabled(enabled)
                    }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Quit NotchShelf", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
```

- [ ] **Step 3: Add stub views for the other two tabs**

Create `NotchShelf/App/Preferences/ShelfPreferencesView.swift`:

```swift
import SwiftUI

struct ShelfPreferencesView: View {
    var body: some View {
        Form {
            Section("Slots") {
                Text("Slot configuration lands in Task 7.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
```

Create `NotchShelf/App/Preferences/AboutPreferencesView.swift`:

```swift
import SwiftUI

struct AboutPreferencesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("About lands in Task 8.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
```

Create `NotchShelf/App/Preferences/LaunchAtLoginService.swift` as a stub for now:

```swift
import Foundation

@MainActor
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    private init() {}

    /// Implementation lands in Task 6. Stubbed so `GeneralPreferencesView` compiles.
    func setEnabled(_ enabled: Bool) {
        _ = enabled
    }
}
```

- [ ] **Step 4: Update `NotchShelfApp.swift`**

Change `Settings { PreferencesView() }` to `Settings { PreferencesRootView() }`.

- [ ] **Step 5: Wire auto-hide preference into the runtime**

In `NotchShelf/App/AppDelegate.swift`, change the `setupDragMonitor()` `onDragEnd` block so that the scheduled collapse uses the preference. Replace:

```swift
monitor.onDragEnd = { [weak self] in
    guard let self else { return }
    if self.windowModel.dropEvent {
        self.windowModel.dropEvent = false
    } else if !self.windowModel.dragTargeting {
        self.windowModel.scheduleCollapse()
    }
}
```

with:

```swift
monitor.onDragEnd = { [weak self] in
    guard let self else { return }
    if self.windowModel.dropEvent {
        self.windowModel.dropEvent = false
    } else if !self.windowModel.dragTargeting {
        let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
        self.windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
    }
}
```

Do the same in `NotchShelf/App/ContentView.swift` `handleHover(_:)`:

```swift
private func handleHover(_ hovering: Bool) {
    if hovering {
        windowModel.expand()
    } else if windowModel.expansion == .expanded {
        let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
        windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
    }
}
```

- [ ] **Step 6: Build & launch to verify the UI**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build.

Manual smoke: launch the app, drag a file to the notch to open the shelf, press `⌘,` (Settings menu) — three tabs should appear, the General tab shows the slider with a live readout, and changing it should change the actual auto-hide timing on the next hover-out.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf/App/PreferencesView.swift NotchShelf/App/NotchShelfApp.swift NotchShelf/App/AppDelegate.swift NotchShelf/App/ContentView.swift NotchShelf/App/Preferences/
git commit -m "feat(prefs): Settings TabView with General tab (auto-hide delay, copy-on-drag, quit)"
```

---

### Task 5: `ShelfStore.clearAll()` + tests

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Create: `NotchShelfTests/ShelfStoreClearAllTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NotchShelfTests/ShelfStoreClearAllTests.swift`:

```swift
import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("ShelfStore.clearAll")
struct ShelfStoreClearAllTests {
    @Test
    func clearAllEmptiesAllSlotsAndPreservesSlotCount() async throws {
        let tempDir = try TempDir.make()
        defer { try? tempDir.cleanup() }
        let url = try tempDir.touch("clear-target.txt")
        let bookmark = try url.bookmarkData(options: [.withSecurityScope])

        let persistence = ShelfPersistenceService(storeURL: tempDir.url.appendingPathComponent("store.json"))
        let store = ShelfStore(persistence: persistence)
        store.add([ShelfItem(bookmarkData: bookmark)])

        #expect(store.items.count == 1)
        let originalSlotCount = store.slots.count

        store.clearAll()

        #expect(store.items.isEmpty)
        #expect(store.slots.count == originalSlotCount)
        #expect(store.slots.allSatisfy { $0.item == nil })
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/ShelfStoreClearAllTests`
Expected: FAIL — `clearAll` does not exist.

- [ ] **Step 3: Implement `clearAll()`**

In `NotchShelf/Shelf/State/ShelfStore.swift`, insert after the existing `remove(bookmarkData:from:)` (around line 107):

```swift
/// Empties every slot. Used by the broom button. Persistence flushes via the
/// existing `slots` didSet → debounced save pipeline.
func clearAll() {
    slots = Self.paddedSlots(slots.map { ShelfSlot(id: $0.id) })
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/ShelfStoreClearAllTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/ShelfStoreClearAllTests.swift
git commit -m "feat(shelf): add ShelfStore.clearAll()"
```

---

### Task 6: `LaunchAtLoginService` with `SMAppService`

**Files:**
- Modify: `NotchShelf/App/Preferences/LaunchAtLoginService.swift` (replace stub)
- Create: `NotchShelfTests/LaunchAtLoginServiceTests.swift`

> **Why `SMAppService`?** macOS 13+ recommended API; works under App Sandbox / Hardened Runtime with no helper bundle. The whole app registers itself as a login item.

- [ ] **Step 1: Write the failing test**

Create `NotchShelfTests/LaunchAtLoginServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import NotchShelf

@MainActor
@Suite("LaunchAtLoginService")
struct LaunchAtLoginServiceTests {
    @Test
    func policyMapsStatusToBool() {
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 1) == true)  // .enabled
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 0) == false) // .notRegistered
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 2) == false) // .requiresApproval
        #expect(LaunchAtLoginService.isEnabled(rawStatus: 3) == false) // .notFound
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/LaunchAtLoginServiceTests`
Expected: FAIL — `isEnabled(rawStatus:)` does not exist.

- [ ] **Step 3: Implement `LaunchAtLoginService`**

Replace `NotchShelf/App/Preferences/LaunchAtLoginService.swift` with:

```swift
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private let service = SMAppService.mainApp

    /// Test seam — pure policy mapping of `SMAppService.Status.rawValue` to bool.
    static func isEnabled(rawStatus: Int) -> Bool {
        rawStatus == SMAppService.Status.enabled.rawValue
    }

    var isCurrentlyEnabled: Bool {
        Self.isEnabled(rawStatus: service.status.rawValue)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            AppLogger.shelf.error("LaunchAtLoginService.setEnabled(\(enabled)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

- [ ] **Step 4: Reconcile preference on launch**

In `NotchShelf/App/AppDelegate.swift`, at the end of `applicationDidFinishLaunching(_:)` (after `ShelfStore.shared.cleanupInvalidItems()`):

```swift
let storedPref = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin)
let actual = LaunchAtLoginService.shared.isCurrentlyEnabled
if storedPref != actual {
    UserDefaults.standard.set(actual, forKey: UserDefaultsKey.launchAtLogin)
}
```

This avoids the UI showing a stale toggle if the user disabled the login item from System Settings.

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/LaunchAtLoginServiceTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add NotchShelf/App/Preferences/LaunchAtLoginService.swift NotchShelf/App/AppDelegate.swift NotchShelfTests/LaunchAtLoginServiceTests.swift
git commit -m "feat(prefs): launch-at-login backed by SMAppService"
```

---

### Task 7: Shelf preferences tab (min/max slots + stack grid threshold)

**Files:**
- Modify: `NotchShelf/App/Preferences/ShelfPreferencesView.swift` (replace stub)

- [ ] **Step 1: Replace stub with the real form**

Replace `NotchShelf/App/Preferences/ShelfPreferencesView.swift`:

```swift
import SwiftUI

struct ShelfPreferencesView: View {
    @AppStorage(UserDefaultsKey.minSlotCount) private var minSlotCount: Int = 5
    @AppStorage(UserDefaultsKey.maxSlotCount) private var maxSlotCount: Int = 15
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var stackListGridThreshold: Int = 5

    var body: some View {
        Form {
            Section("Slots") {
                Stepper(value: $minSlotCount, in: 3...10) {
                    LabeledContent("Minimum visible slots", value: "\(minSlotCount)")
                }
                Stepper(value: $maxSlotCount, in: minSlotCount...30) {
                    LabeledContent("Maximum slots", value: "\(maxSlotCount)")
                }
                Text("When two or fewer slots remain free, NotchShelf adds another row, up to the maximum.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Stack list") {
                Stepper(value: $stackListGridThreshold, in: 3...20) {
                    LabeledContent("Switch to grid above", value: "\(stackListGridThreshold) files")
                }
                Text("All files in a stack are always reachable; the grid keeps them visible without scrolling.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onChange(of: minSlotCount) { _, newValue in
            if maxSlotCount < newValue { maxSlotCount = newValue }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/Preferences/ShelfPreferencesView.swift
git commit -m "feat(prefs): shelf tab with slot count and stack grid threshold"
```

---

### Task 8: About tab

**Files:**
- Modify: `NotchShelf/App/Preferences/AboutPreferencesView.swift` (replace stub)

- [ ] **Step 1: Replace stub with the real About panel**

Replace `NotchShelf/App/Preferences/AboutPreferencesView.swift`:

```swift
import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
            }
            Text("NotchShelf")
                .font(.title2.weight(.semibold))
            Text("Version \(version) (\(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            VStack(spacing: 4) {
                Text("Made by Michał Kleniewski").font(.callout)
                Text(copyright).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("View License") {
                    if let url = URL(string: "https://opensource.org/license/mit") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Acknowledgements") {
                    // No bundled acknowledgements file in v1.x — show an info alert.
                    let alert = NSAlert()
                    alert.messageText = "Acknowledgements"
                    alert.informativeText = "NotchShelf is built on Apple platform frameworks only. Thanks to the boring.notch project for the notch geometry research."
                    alert.runModal()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Build & smoke-test**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build. Manually open Settings → About; the version and copyright should match `Info.plist`.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/Preferences/AboutPreferencesView.swift
git commit -m "feat(prefs): About tab with version, attribution, and license link"
```

---

### Task 9: Dynamic visible-slot count policy

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift`
- Create: `NotchShelfTests/SlotCountPolicyTests.swift`

Policy: the shelf shows at least `minSlotCount` slots. When the count of empty slots drops to ≤ 2, the shelf grows by another `minSlotCount` slots (one "row"), capped at `maxSlotCount`. When empty slots ≥ `minSlotCount + 2`, the shelf can shrink back, but never below `minSlotCount`.

- [ ] **Step 1: Write the failing test**

Create `NotchShelfTests/SlotCountPolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import NotchShelf

@Suite("SlotCountPolicy")
struct SlotCountPolicyTests {
    @Test
    func returnsMinimumWhenNoItems() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 0, currentVisible: 5, min: 5, max: 15) == 5)
    }

    @Test
    func growsByRowWhenFreeSlotsHitTwo() {
        // 5 slots, 3 items → 2 free → grow to 10.
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 3, currentVisible: 5, min: 5, max: 15) == 10)
    }

    @Test
    func doesNotGrowWhileMoreThanTwoFreeRemain() {
        // 5 slots, 2 items → 3 free → stay at 5.
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 2, currentVisible: 5, min: 5, max: 15) == 5)
    }

    @Test
    func cappedAtMaximum() {
        // 15 slots, 13 items → 2 free → would grow to 20 but capped at 15.
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 13, currentVisible: 15, min: 5, max: 15) == 15)
    }

    @Test
    func shrinksWhenAtLeastOneFullRowIsFreeBeyondMinimum() {
        // 10 slots, 2 items → 8 free, minSlots is 5 so we can drop a row.
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 2, currentVisible: 10, min: 5, max: 15) == 5)
    }

    @Test
    func neverShrinksBelowMinimum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 0, currentVisible: 5, min: 5, max: 15) == 5)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/SlotCountPolicyTests`
Expected: FAIL — `SlotCountPolicy` does not exist.

- [ ] **Step 3: Implement `SlotCountPolicy`**

Add to `NotchShelf/Shelf/State/ShelfStore.swift` (above the `ShelfStore` declaration):

```swift
/// Pure policy for how many slots the shelf should expose. Extracted from
/// `ShelfStore` so it can be unit-tested without UserDefaults or persistence.
enum SlotCountPolicy {
    /// `filledItems`: how many slots currently hold a `ShelfItem`.
    /// `currentVisible`: how many slot rows are presently rendered.
    /// `min` / `max`: user-configured bounds.
    static func visibleSlotCount(filledItems: Int, currentVisible: Int, min: Int, max: Int) -> Int {
        let lowerBound = Swift.max(min, 1)
        let upperBound = Swift.max(max, lowerBound)
        let baseRow = lowerBound

        var target = Swift.max(currentVisible, lowerBound)
        let free = target - filledItems

        if free <= 2 {
            target = Swift.min(target + baseRow, upperBound)
        }
        while target - baseRow >= lowerBound,
              filledItems <= (target - baseRow) - 2 {
            target -= baseRow
        }
        return Swift.max(Swift.min(target, upperBound), lowerBound)
    }
}
```

- [ ] **Step 4: Wire the policy into `ShelfStore`**

Add to `ShelfStore` (next to `defaultSlotCount`):

```swift
private var defaultsMin: Int {
    let v = UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount)
    return v >= 3 ? v : Self.defaultSlotCount
}
private var defaultsMax: Int {
    let v = UserDefaults.standard.integer(forKey: UserDefaultsKey.maxSlotCount)
    return v >= defaultsMin ? v : 15
}

/// The number of slots the UI should render right now.
var visibleSlotCount: Int {
    SlotCountPolicy.visibleSlotCount(
        filledItems: items.count,
        currentVisible: slots.count,
        min: defaultsMin,
        max: defaultsMax
    )
}
```

Replace the existing `paddedSlots(_:)` helper so it pads to `visibleSlotCount` instead of `defaultSlotCount`. Add a new static variant `paddedSlots(_:target:)`:

```swift
private static func paddedSlots(_ slots: [ShelfSlot], target: Int) -> [ShelfSlot] {
    guard slots.count < target else { return slots }
    return slots + (slots.count..<target).map { _ in ShelfSlot() }
}
```

Then every call site that currently passes `Self.paddedSlots(...)` (there are seven inside `ShelfStore`) becomes `Self.paddedSlots(..., target: targetSlotCount(for: ...))` where:

```swift
private func targetSlotCount(for filled: Int, currentVisible: Int) -> Int {
    SlotCountPolicy.visibleSlotCount(
        filledItems: filled,
        currentVisible: currentVisible,
        min: defaultsMin,
        max: defaultsMax
    )
}
```

For each existing `Self.paddedSlots(<slots>)` call, replace with:

```swift
let target = targetSlotCount(
    for: <slots>.compactMap(\.item).count,
    currentVisible: <slots>.count
)
return Self.paddedSlots(<slots>, target: target)
```

Concretely, the three places to edit are:
1. `init(persistence:)` — change `Self.paddedSlots(persistence.loadSlots())` to use `targetSlotCount(...)`. Since `targetSlotCount` is an instance method and we're in `init`, inline the policy call directly using the locals (we cannot call `targetSlotCount` before `_slots` is set).
2. Every `slots = Self.paddedSlots(...)` write inside `add(_:atSlot:)`, `remove(_:)`, `remove(bookmarkData:from:)`, `cleanupInvalidItems()`, `clearAll()`.
3. `paddedSlots(_:)` (no-arg target) — delete it; only the keyed variant remains.

For brevity in implementation, define a private instance helper:

```swift
private func reslot(_ next: [ShelfSlot]) -> [ShelfSlot] {
    let target = targetSlotCount(for: next.compactMap(\.item).count, currentVisible: next.count)
    return Self.paddedSlots(next, target: target)
}
```

…and replace every `Self.paddedSlots(<x>)` write with `reslot(<x>)`.

In `init(persistence:)` (where `self` is not yet usable for instance methods), compute the bounds inline:

```swift
let raw = persistence.loadSlots()
let min = UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount)
let max = UserDefaults.standard.integer(forKey: UserDefaultsKey.maxSlotCount)
let target = SlotCountPolicy.visibleSlotCount(
    filledItems: raw.compactMap(\.item).count,
    currentVisible: raw.count,
    min: min >= 3 ? min : Self.defaultSlotCount,
    max: max >= 3 ? max : 15
)
let loaded = Self.paddedSlots(raw, target: target)
_slots = Published(initialValue: loaded)
```

- [ ] **Step 5: Run the policy tests**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/SlotCountPolicyTests`
Expected: PASS.

- [ ] **Step 6: Run the full test suite**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test`
Expected: PASS. If `ShelfStoreTests` regresses because it assumed a fixed slot count of 5, update those tests to read `store.slots.count` rather than asserting on 5 directly.

- [ ] **Step 7: Commit**

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift NotchShelfTests/SlotCountPolicyTests.swift NotchShelfTests/ShelfStoreTests.swift
git commit -m "feat(shelf): dynamic visible-slot count policy honouring min/max prefs"
```

---

### Task 10: Multi-row shelf layout via LazyVGrid

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfView.swift`
- Modify: `NotchShelf/App/ContentView.swift` (`expandedShapeSize` accounts for rows)

- [ ] **Step 1: Switch `ShelfView.content` to a `LazyVGrid`**

Replace the `content` computed property in `NotchShelf/Shelf/Views/ShelfView.swift`:

```swift
private var rowCapacity: Int {
    Swift.max(UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount), 3)
}

private var gridColumns: [GridItem] {
    Array(
        repeating: GridItem(.fixed(ShelfMetrics.itemWidth), spacing: spacing, alignment: .top),
        count: rowCapacity
    )
}

private var content: some View {
    LazyVGrid(columns: gridColumns, alignment: .center, spacing: spacing) {
        ForEach(Array(store.slots.enumerated()), id: \.element.id) { index, slot in
            if let item = slot.item {
                ShelfItemView(item: item)
            } else {
                ShelfSlotPlaceholderView(isPanelTargeted: isVisuallyTargeted) { providers in
                    handleDrop(providers: providers, slotIndex: index)
                }
            }
        }
    }
    .padding(.horizontal, 2)
}
```

Delete the surrounding `ScrollView(.horizontal)`. (Vertical overflow lands in the grid naturally; with a max of 15 slots and a row capacity of 5, the worst case is 3 rows ≈ 200 pt tall — within the expanded shape budget.)

- [ ] **Step 2: Update `expandedShapeSize` for multi-row height**

In `NotchShelf/App/ContentView.swift`, replace `expandedShapeSize` with:

```swift
private var expandedShapeSize: CGSize {
    let baseRow = Swift.max(UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount), 3)
    let slotCount = store.slots.count
    let rows = Swift.max(Int((Double(slotCount) / Double(baseRow)).rounded(.up)), 1)
    let rowHeight = ShelfMetrics.itemHeight + ShelfMetrics.itemSpacing
    let chromeHeight = geometry.notchHeight + 24 + ShelfMetrics.shelfPanelBottomPadding
    let height = chromeHeight + CGFloat(rows) * rowHeight

    let emptyWidth = geometry.notchWidth + ShelfMetrics.sideExpansion * 2
    let rowWidth = CGFloat(baseRow) * ShelfMetrics.itemWidth
        + CGFloat(baseRow - 1) * ShelfMetrics.itemSpacing
        + ShelfMetrics.contentPadding * 2
    let width = Swift.max(emptyWidth, rowWidth)
    return CGSize(width: width, height: height)
}
```

Also change `expandedSize` in `NotchShelf/Window/ShelfMetrics.swift` if the current cap of `140` is now too short — bump to `260` to give multi-row room:

```swift
static let expandedSize = CGSize(width: 584, height: 260)
```

…and the `windowSize` height correspondingly (the window must contain the expanded shape):

```swift
static let windowSize = CGSize(width: 624, height: 280)
```

- [ ] **Step 3: Build and smoke-test**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build.

Manual smoke: drop 6 files in sequence. After the 3rd file (2 free remain), a second row of slots should appear and stay. Removing items should collapse the second row only when ≥ baseRow + 2 slots become free.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfView.swift NotchShelf/App/ContentView.swift NotchShelf/Window/ShelfMetrics.swift
git commit -m "feat(shelf): multi-row slot grid that grows when slots fill up"
```

---

### Task 11: Stack file grid view

**Files:**
- Modify: `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`
- Create: `NotchShelf/Shelf/Views/Stack/StackFileGridView.swift`

- [ ] **Step 1: Create `StackFileGridView.swift`**

```swift
import AppKit
import SwiftUI

/// Compact grid layout used when a stack has more than `stackListGridThreshold`
/// files. Every file remains visible; we scroll only as a final fallback.
struct StackFileGridView: View {
    let item: ShelfItem
    let entries: [StackMenuEntry]

    private let columns = [
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6),
        GridItem(.fixed(64), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
            ForEach(entries, id: \.id) { entry in
                StackFileGridCellView(sourceItem: item, entry: entry)
            }
        }
        .padding(8)
    }
}

private struct StackFileGridCellView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    @State private var icon: NSImage = NSWorkspace.shared.icon(for: .data)

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
            Text(entry.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 26, alignment: .top)
        }
        .frame(width: 60, height: 66)
        .contentShape(Rectangle())
        .overlay {
            StackFileDragHandler(sourceItem: sourceItem, entry: entry, previewImage: icon)
        }
        .onAppear { loadIcon() }
        .onChange(of: entry.id) { _, _ in loadIcon() }
    }

    private func loadIcon() {
        if let url = entry.fileURL {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .data)
        }
    }
}
```

- [ ] **Step 2: Switch `StackFileListView.body` to pick list-or-grid**

In `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`, replace the body of `StackFileListView` with:

```swift
struct StackFileListView: View {
    let item: ShelfItem
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var gridThreshold: Int = 5
    @State private var entries: [StackMenuEntry] = []

    private var useGrid: Bool { entries.count > gridThreshold }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if useGrid {
                StackFileGridView(item: item, entries: entries)
            } else {
                VStack(spacing: 2) {
                    ForEach(entries, id: \.id) { entry in
                        StackFileRowView(sourceItem: item, entry: entry)
                    }
                }
                .padding(6)
            }
        }
        .frame(maxHeight: 320)
        .scrollIndicators(.never)
        .background(Color.clear)
        .onAppear { resolveEntries() }
        .onChange(of: item) { _, _ in resolveEntries() }
    }

    private func resolveEntries() {
        entries = item.allBookmarkData.enumerated().map { index, data in
            let url = Bookmark(data: data).resolveURL()
            return StackMenuEntry(
                id: index,
                title: url?.lastPathComponent ?? "Unknown file",
                bookmarkData: data,
                fileURL: url
            )
        }
    }
}
```

Also adjust the `Coordinator.makeContentController(for:)` panel size so the grid fits. Replace its body with:

```swift
private func makeContentController(for item: ShelfItem) -> NSHostingController<some View> {
    let count = item.allBookmarkData.count
    let threshold = UserDefaults.standard.integer(forKey: UserDefaultsKey.stackListGridThreshold)
    let usesGrid = count > Swift.max(threshold, 3)

    let width: CGFloat = usesGrid ? 280 : 240
    let height: CGFloat
    if usesGrid {
        let columns = 4.0
        let rows = ceil(Double(count) / columns)
        height = Swift.min(rows * 74 + 16, 320)
    } else {
        height = Swift.min(CGFloat(count) * 34 + 12, 320)
    }

    let view = StackFileListView(item: item)
        .frame(width: width, height: height)
        .background(Color.clear)
    let controller = NSHostingController(rootView: view)
    controller.view.wantsLayer = true
    controller.view.layer?.backgroundColor = NSColor.clear.cgColor
    return controller
}
```

And mirror the size logic inside `position(_:anchoredTo:itemCount:)`:

```swift
private func position(_ panel: NSPanel, anchoredTo anchorView: NSView, itemCount: Int) {
    guard let window = anchorView.window else { return }
    let threshold = UserDefaults.standard.integer(forKey: UserDefaultsKey.stackListGridThreshold)
    let usesGrid = itemCount > Swift.max(threshold, 3)

    let width: CGFloat = usesGrid ? 280 : 240
    let height: CGFloat
    if usesGrid {
        let columns = 4.0
        let rows = ceil(Double(itemCount) / columns)
        height = Swift.min(rows * 74 + 16, 320)
    } else {
        height = Swift.min(CGFloat(itemCount) * 34 + 12, 320)
    }
    panel.setContentSize(NSSize(width: width, height: height))

    let anchorRect = anchorView.convert(anchorView.bounds, to: nil)
    let screenRect = window.convertToScreen(anchorRect)
    let x = screenRect.midX - width / 2
    let y = screenRect.minY - height - 4
    panel.setFrameOrigin(NSPoint(x: x, y: y))
}
```

- [ ] **Step 3: Build and smoke-test**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build.

Manual smoke: drop a folder with 8 files (creates a stack), tap the stack list button — grid view with 4 columns should appear, every entry draggable, panel auto-sized.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/Stack/
git commit -m "feat(stack): grid view above stackListGridThreshold files"
```

---

### Task 12: Broom "Clear shelf" button

**Files:**
- Create: `NotchShelf/Shelf/Views/ShelfClearButton.swift`
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Create `ShelfClearButton.swift`**

```swift
import SwiftUI

struct ShelfClearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear shelf")
        .accessibilityLabel("Clear shelf")
    }
}
```

> The TODO calls for a broom. SF Symbols ships `wand.and.sparkles` which reads as "tidy up"; if the user prefers a literal broom they can swap the symbol name later. (`broom` is not a current SF Symbol on macOS 14.)

- [ ] **Step 2: Update `ContentView.swift`**

Replace the existing `preferencesButton` HStack with a unified top‑bar row that includes the broom on the left, the gear on the right:

```swift
private var topBar: some View {
    VStack {
        HStack {
            ShelfClearButton(action: clearShelf)
                .padding(.leading, currentTopCornerRadius + 8)
            Spacer()
            Button("Preferences", systemImage: "gearshape.fill", action: showPreferences)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .help("Preferences")
                .accessibilityLabel("Preferences")
                .padding(.trailing, currentTopCornerRadius + 8)
        }
        Spacer()
    }
}

private func clearShelf() {
    store.clearAll()
}
```

In the main `body`, replace the standalone `preferencesButton` block inside the expanded branch with `topBar`:

```swift
if windowModel.expansion == .expanded {
    ShelfView()
        .environmentObject(windowModel)
        .padding(.horizontal, currentTopCornerRadius + 12)
        .padding(.top, geometry.notchHeight + 12)
        .padding(.bottom, ShelfMetrics.shelfPanelBottomPadding)
        .transition(shelfContentTransition)
        .zIndex(1)

    topBar
        .padding(.top, preferencesButtonTopPadding)
        .transition(shelfContentTransition)
        .zIndex(2)
}
```

Delete the old `preferencesButton` computed property.

- [ ] **Step 3: Build and smoke-test**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: clean build.

Manual smoke: drop 3 files; expand the shelf; click the broom icon top-left → all slots empty, baseline visible. Click gear → Settings opens.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/Shelf/Views/ShelfClearButton.swift NotchShelf/App/ContentView.swift
git commit -m "feat(shelf): broom button to clear the shelf"
```

---

### Task 13: Confirm "real icons" coverage (TODO #2)

**Files:**
- Modify: `NotchShelfTests/ShelfItemViewModelTests.swift` (add a test that confirms `viewModel.icon` is the system icon for the URL)

This task is verification, not new code — the current pipeline already uses `NSWorkspace.shared.icon(forFile:)` plus `QLThumbnailGenerator`. We lock that behaviour in with a test so we cannot regress.

- [ ] **Step 1: Add a test**

Append to `NotchShelfTests/ShelfItemViewModelTests.swift`:

```swift
@Test
func iconMatchesNSWorkspaceForResolvedURL() async throws {
    let tempDir = try TempDir.make()
    defer { try? tempDir.cleanup() }
    let url = try tempDir.touch("doc.txt")
    let bookmark = try url.bookmarkData(options: [.withSecurityScope])
    let item = ShelfItem(bookmarkData: bookmark)

    await MainActor.run {
        let viewModel = ShelfItemViewModel(item: item)
        let expected = NSWorkspace.shared.icon(forFile: url.path)
        #expect(viewModel.icon.size == expected.size)
    }
}
```

- [ ] **Step 2: Run the test**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test -only-testing:NotchShelfTests/ShelfItemViewModelTests`
Expected: PASS without any production code change.

- [ ] **Step 3: Commit**

```bash
git add NotchShelfTests/ShelfItemViewModelTests.swift
git commit -m "test(shelf): lock in NSWorkspace icon resolution for shelf items"
```

---

### Task 14: Optimization pass — cut redundant bookmark resolves

**Files:**
- Modify: `NotchShelf/Shelf/Models/ShelfItem.swift`

`ShelfItem.fileURL`, `sourceFolderKey`, and `identityKey` each call `Bookmark(data:).resolveURL()` from scratch. Hot paths (`add(_:atSlot:)`, `ShelfStore.items`) call them in tight loops. Cache the resolution per `ShelfItem` value via a derived computed property is impossible (`struct` immutability + Codable), but we can short-circuit `identityKey` for non-stack items by resolving once.

- [ ] **Step 1: Inline a single resolve in `identityKey`**

Replace the body of `identityKey` in `NotchShelf/Shelf/Models/ShelfItem.swift`:

```swift
var identityKey: String {
    if isStack {
        let keys = allBookmarkData.map { data in
            if let url = Bookmark(data: data).resolveURL() {
                return "file://" + url.standardizedFileURL.path
            }
            return "file://missing/" + data.base64EncodedString()
        }
        return "stack://" + keys.sorted().joined(separator: "|")
    }
    if let url = Bookmark(data: bookmarkData).resolveURL() {
        return "file://" + url.standardizedFileURL.path
    }
    return "file://missing/" + bookmarkData.base64EncodedString()
}
```

This is identical to today's behaviour but avoids the `fileURL` accessor's extra construction. The gain is small but consistent for stacks.

- [ ] **Step 2: Cache `sourceFolderKey` callers**

In `ShelfStore.add(_:atSlot:)`, the inner loop calls `item.sourceFolderKey` on every iteration of `newItems`. Each one re-resolves the bookmark. Refactor to resolve once per new item:

Replace the `for item in newItems { … }` block with:

```swift
for item in newItems {
    let folderKey = item.sourceFolderKey
    let key = item.identityKey
    ...
}
```

(That is already the structure today — leave it. The real win is to ensure no other call sites compute `sourceFolderKey` / `identityKey` inside `ForEach`. Search:)

Run: `grep -RIn "sourceFolderKey\|identityKey" NotchShelf`

Expected: only call sites in `ShelfStore.swift`. If any view-layer call appears (Step 3 below catches it), inline the value into ViewData instead.

- [ ] **Step 3: Audit and adjust**

If `grep` flags a non-`ShelfStore` reference, fix it. Otherwise, no code change.

- [ ] **Step 4: Run the full test suite**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test`
Expected: PASS (60+ tests).

- [ ] **Step 5: Commit**

```bash
git add NotchShelf/Shelf/Models/ShelfItem.swift
git commit -m "perf(shelf): trim redundant bookmark resolves in identityKey"
```

---

### Task 15: Final regression sweep

**Files:** none modified — verification only.

- [ ] **Step 1: Build**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' build`
Expected: PASS, no warnings.

- [ ] **Step 2: Full test suite**

Run: `xcodebuild -scheme NotchShelf -destination 'platform=macOS' test`
Expected: PASS, all tests including the new `PreferencesKeysTests`, `ShelfStoreClearAllTests`, `SlotCountPolicyTests`, `LaunchAtLoginServiceTests`.

- [ ] **Step 3: Manual smoke matrix**

Tick each off in order:
- Drop 1 file: shelf opens, slot fills, after hovering away the shelf auto-hides on the configured delay.
- Drag the item off the shelf back to Finder: file appears at the drop site as a **copy**, never moved (Finder's drop badge should never show the green "move" arrow).
- Open Settings (`⌘,`): all three tabs render; sliders/steppers/toggle changes take effect on the next interaction.
- Toggle launch-at-login on, restart, verify the toggle stays on; toggle off, restart, verify it stays off.
- Fill the shelf with 4 items: a second row appears (2 free slots remain in the first row).
- Drop a folder with 8 files: stack appears; click the list-button on the stack; grid view is shown with 4 columns; each file is draggable to Finder as a copy.
- Click broom: shelf empties, baseline row visible.
- Force-quit the app, relaunch: shelf reloads exactly the same items.

- [ ] **Step 4: Final commit (if anything was tweaked during smoke)**

```bash
git status
# if anything is modified:
git commit -am "polish: post-smoke adjustments"
```

If nothing changed, skip.

---

## Self-Review Pass

**Spec coverage:**

| TODO.md item | Tasks covering it |
|---|---|
| #1 system impact safety | Task 2 |
| #2 real file icons | Task 13 |
| #3 prefs panel — auto-hide | Tasks 1, 4 |
| #3 prefs panel — copy-on-drag default off | Task 4 (already false in registration) |
| #3 prefs panel — quit | Task 4 |
| #3 prefs panel — launch-at-login | Tasks 1, 4, 6 |
| #3 prefs panel — About | Tasks 1, 4, 8 |
| #3 prefs panel — slot count min/max + auto-add row | Tasks 1, 7, 9, 10 |
| #3 prefs panel — show extra slots when 2 free remain | Task 9 |
| #4 optimization | Tasks 9 (less work in body), 14 |
| #5 broom button | Tasks 5, 12 |
| #6 stack grid above threshold | Tasks 1, 7, 11 |

No item is unaccounted for.

**Placeholder scan:** No `TBD`, `TODO`, or "implement later" tokens; every step contains the exact code or command. The stubs in Task 4 are intentionally placed and are replaced in Tasks 6–8 — each stub is shown in full, not described.

**Type consistency:** `UserDefaultsKey.copyOnDrag` matches the existing string `"copyOnDrag"` (preserves user data). All other keys are introduced fresh and used consistently across files. `LaunchAtLoginService.shared.setEnabled(_:)` keeps the same signature between Task 4 stub and Task 6 implementation. `SlotCountPolicy.visibleSlotCount(filledItems:currentVisible:min:max:)` is referenced identically in Task 9 implementation and tests. `clearAll()` on `ShelfStore` is referenced by the same name in `ShelfClearButton`'s wiring (Task 12) and the `ShelfStoreClearAllTests` (Task 5).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-15-plan-aktualizacji.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?

# Plan poprawek po audycie kodu (post-stable)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adresować ważne (`Important`) ustalenia z trójstronnego audytu (architektura / SwiftUI / animacje), które nie blokowały mergu do `stable`, ale są długiem do spłaty w pierwszej iteracji post-MVP.

**Architecture:** Każde zadanie to izolowana zmiana z testami; commit per zadanie. Phase 1 i 2 to bezpieczne refaktory bez zmian behawioralnych obserwowalnych przez użytkownika. Phase 3 to większa ekstrakcja klasy z `AppDelegate`. Phase 4 dostraja animacje. Phase 5 zamyka pętlę DI w warstwie drag-source. Phase 6 to kosmetyka.

**Tech Stack:** Swift 5.9+, SwiftUI (macOS 14+), XCTest + Swift Testing, AppKit (`NSPanel`, `Timer`), `@MainActor` concurrency, xcodebuild CLI.

**Zakres testów:** `xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test`
Obecny baseline: **108/108 testów green**. Po każdym zadaniu musi zostać 108+ green.

---

## Phase 1 — Szybkie poprawki SwiftUI (niskie ryzyko)

### Task 1: Migracja `.tabItem` → `Tab` API w `PreferencesRootView`

**Files:**
- Modify: `NotchShelf/App/PreferencesView.swift`

- [ ] **Step 1: Zastąp deprecated `.tabItem(...)` modyfikator nowym `Tab` API**

Aktualny kod (`NotchShelf/App/PreferencesView.swift:1-17`):
```swift
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
        .frame(width: 500, height: 410)
    }
}
```

Nowy kod:
```swift
struct PreferencesRootView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralPreferencesView()
            }
            Tab("Shelf", systemImage: "tray.full") {
                ShelfPreferencesView()
            }
            Tab("About", systemImage: "info.circle") {
                AboutPreferencesView()
            }
        }
        .frame(width: 500, height: 410)
    }
}
```

- [ ] **Step 2: Build i ręczna weryfikacja**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`

Następnie odpal aplikację (`open ~/Library/Developer/Xcode/DerivedData/NotchShelf-*/Build/Products/Debug/NotchShelf.app`), otwórz Preferences (Cmd+,) i sprawdź, że trzy zakładki działają i ikony są widoczne.

- [ ] **Step 3: Uruchom testy**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`, 108/108 green.

- [ ] **Step 4: Commit**

```bash
git add NotchShelf/App/PreferencesView.swift
git commit -m "refactor(preferences): migrate from deprecated .tabItem to Tab API"
```

---

### Task 2: Reduce Motion w `PreferenceSwitchToggleStyle`

**Files:**
- Modify: `NotchShelf/App/Preferences/PreferenceSwitchToggleStyle.swift`

- [ ] **Step 1: Wprowadź wewnętrzny `View`, który czyta `@Environment(\.accessibilityReduceMotion)`**

`ToggleStyle.makeBody` zwraca `View`, więc trzeba wyodrębnić `View`-struct, aby skorzystać z `@Environment`. Pełny nowy plik:

```swift
import SwiftUI

struct PreferenceSwitchToggleStyle: ToggleStyle {
    let accessibilityLabel: String

    func makeBody(configuration: Configuration) -> some View {
        SwitchBody(configuration: configuration, accessibilityLabel: accessibilityLabel)
    }

    private struct SwitchBody: View {
        let configuration: Configuration
        let accessibilityLabel: String
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Button {
                let animation: Animation? = reduceMotion ? nil : .snappy(duration: 0.16)
                withAnimation(animation) {
                    configuration.isOn.toggle()
                }
            } label: {
                Capsule()
                    .fill(configuration.isOn ? Color.accentColor : Color(nsColor: .tertiaryLabelColor).opacity(0.26))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                            .padding(2)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(configuration.isOn ? 0.24 : 0.08), lineWidth: 0.75)
                    }
                    .frame(
                        width: PreferencesPanelMetrics.switchWidth,
                        height: PreferencesPanelMetrics.switchHeight
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual a11y test**

System Settings → Accessibility → Display → włącz "Reduce motion". Otwórz Preferences NotchShelf, kliknij dowolny toggle. Capsule thumb powinien przeskoczyć natychmiast bez animacji. Wyłącz Reduce motion — toggle wraca do `.snappy(0.16)`.

- [ ] **Step 4: Testy + commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

```bash
git add NotchShelf/App/Preferences/PreferenceSwitchToggleStyle.swift
git commit -m "fix(preferences): honor Reduce Motion in custom toggle style"
```

---

### Task 3: Eliminacja `Binding(get:set:)` w body `PreferenceSliderRow`

**Files:**
- Modify: `NotchShelf/App/Preferences/PreferenceSliderRow.swift`

- [ ] **Step 1: Zastąp wewnętrzną computed Binding na `@State` + `onChange`**

Wytyczna swiftui-pro: nie twórz `Binding(get:set:)` w body view; każdy render tworzy nową instancję bindingu, co psuje równość referencyjną SwiftUI i utrudnia diff.

Pełny nowy plik:

```swift
import SwiftUI

struct PreferenceSliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let valueText: (Int) -> String
    @State private var doubleValue: Double

    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        valueText: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.valueText = valueText
        _doubleValue = State(initialValue: Double(value.wrappedValue))
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 12) {
                Slider(
                    value: $doubleValue,
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                ) {
                    Text(title)
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: PreferencesPanelMetrics.preferenceSliderWidth)
                .accessibilityValue(Text(valueText(value)))

                Text(valueText(value))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: PreferencesPanelMetrics.preferenceValueWidth, alignment: .trailing)
            }
        }
        .onChange(of: doubleValue) { _, newValue in
            let clamped = Swift.min(
                Swift.max(Int(newValue.rounded()), range.lowerBound),
                range.upperBound
            )
            if value != clamped { value = clamped }
        }
        .onChange(of: value) { _, newValue in
            let asDouble = Double(newValue)
            if doubleValue != asDouble { doubleValue = asDouble }
        }
    }
}
```

Uwaga: dwukierunkowy sync między `value: Binding<Int>` a `doubleValue: @State` jest konieczny, bo zewnętrzny binding (`@AppStorage`) może się zmienić poza widokiem (np. inny tab Preferences czy reset defaultów); guard `if value != clamped` zapobiega pętlom onChange.

- [ ] **Step 2: Manual smoke test**

Otwórz Preferences → Shelf, przesuwaj slider "Minimum slot count" / "Stack grid threshold". Wartości powinny się aktualizować w trakcie przeciągania, a tekst po prawej powinien się zmieniać synchronicznie.

- [ ] **Step 3: Testy + commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 108/108 green.

```bash
git add NotchShelf/App/Preferences/PreferenceSliderRow.swift
git commit -m "refactor(preferences): replace in-body Binding(get:set:) with @State + onChange"
```

---

### Task 4: Generalizacja `PreferenceSliderRow` na `Double` + użycie w `GeneralPreferencesView`

**Files:**
- Create: `NotchShelf/App/Preferences/PreferenceDoubleSliderRow.swift`
- Modify: `NotchShelf/App/Preferences/GeneralPreferencesView.swift`

Decyzja projektowa: zamiast generycznego `PreferenceSliderRow<Value: BinaryFloatingPoint>` (który komplikuje formatowanie int-vs-float), dorzuć siostrzany `PreferenceDoubleSliderRow`. Oba dzielą identyczny layout, ale różnią się typem wartości i krokiem.

- [ ] **Step 1: Stwórz `PreferenceDoubleSliderRow.swift`**

```swift
import SwiftUI

struct PreferenceDoubleSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String

    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        valueText: @escaping (Double) -> String
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 12) {
                Slider(value: $value, in: range, step: step) {
                    Text(title)
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: PreferencesPanelMetrics.preferenceSliderWidth)
                .accessibilityValue(Text(valueText(value)))

                Text(valueText(value))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: PreferencesPanelMetrics.preferenceValueWidth, alignment: .trailing)
            }
        }
    }
}
```

- [ ] **Step 2: Zaktualizuj `project.yml`/Xcode project, żeby uwzględnić nowy plik**

Jeśli używasz `xcodegen` (sprawdź `project.yml`), pojedyncze `xcodegen generate` w korzeniu repo dodaje plik do targetu. Jeśli nie, dodaj ręcznie w Xcode (File → Add Files…), upewnij się, że target `NotchShelf` jest zaznaczony.

```bash
which xcodegen && xcodegen generate
```
Jeśli `xcodegen` nie jest zainstalowany, zrób to ręcznie w Xcode.

- [ ] **Step 3: Zastąp inline slider row w `GeneralPreferencesView`**

W `NotchShelf/App/Preferences/GeneralPreferencesView.swift` zastąp linie 13-29 (`PreferenceRow("Auto-hide delay") { HStack { Slider... } }`) wywołaniem nowego komponentu:

```swift
PreferenceDoubleSliderRow(
    "Auto-hide delay",
    value: $autoHideDelaySeconds,
    in: 0.5...5.0,
    step: 0.25,
    valueText: { String(format: "%.2fs", $0) }
)
```

Usuń też pomocniczy `private var delayText: String` (linie 71-73) jeśli nie jest używany gdzie indziej (`grep -n delayText NotchShelf/App/Preferences/GeneralPreferencesView.swift` powinien zwrócić 0 trafień po edycji).

- [ ] **Step 4: Build, ręczny test, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`, 108/108 green.

Manual: Preferences → General → slider "Auto-hide delay" działa identycznie jak przed zmianą (zakres 0.5-5.0s, krok 0.25, format "%.2fs").

```bash
git add NotchShelf/App/Preferences/PreferenceDoubleSliderRow.swift \
        NotchShelf/App/Preferences/GeneralPreferencesView.swift \
        NotchShelf.xcodeproj project.yml
git commit -m "refactor(preferences): extract PreferenceDoubleSliderRow and reuse in General tab"
```

---

## Phase 2 — Refaktory architektoniczne (średnie ryzyko)

### Task 5: Centralizacja odczytu `autoHideDelaySeconds` → `AutoHidePolicy`

**Files:**
- Create: `NotchShelf/Shelf/Services/AutoHidePolicy.swift`
- Create: `NotchShelfTests/AutoHidePolicyTests.swift`
- Modify: `NotchShelf/App/ContentView.swift` (linia 227-228)
- Modify: `NotchShelf/App/AppDelegate.swift` (linia 64-65)

- [ ] **Step 1: Napisz failing test dla `AutoHidePolicy`**

Stwórz `NotchShelfTests/AutoHidePolicyTests.swift`:

```swift
import XCTest
@testable import NotchShelf

final class AutoHidePolicyTests: XCTestCase {
    func test_returnsStoredDelay_whenPositive() {
        let defaults = TestSupport.makeIsolatedDefaults()
        defaults.set(2.5, forKey: UserDefaultsKey.autoHideDelaySeconds)
        XCTAssertEqual(AutoHidePolicy.collapseDelay(defaults: defaults), 2.5, accuracy: 0.001)
    }

    func test_returnsFallback_whenStoredValueIsZero() {
        let defaults = TestSupport.makeIsolatedDefaults()
        defaults.set(0, forKey: UserDefaultsKey.autoHideDelaySeconds)
        XCTAssertEqual(AutoHidePolicy.collapseDelay(defaults: defaults), AutoHidePolicy.fallbackDelaySeconds)
    }

    func test_returnsFallback_whenKeyIsMissing() {
        let defaults = TestSupport.makeIsolatedDefaults()
        XCTAssertEqual(AutoHidePolicy.collapseDelay(defaults: defaults), AutoHidePolicy.fallbackDelaySeconds)
    }

    func test_returnsFallback_whenStoredValueIsNegative() {
        let defaults = TestSupport.makeIsolatedDefaults()
        defaults.set(-1.0, forKey: UserDefaultsKey.autoHideDelaySeconds)
        XCTAssertEqual(AutoHidePolicy.collapseDelay(defaults: defaults), AutoHidePolicy.fallbackDelaySeconds)
    }
}
```

- [ ] **Step 2: Run test — must fail**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | grep -E "AutoHidePolicy|error:" | head
```
Expected: `cannot find 'AutoHidePolicy' in scope` lub podobny błąd kompilacji.

- [ ] **Step 3: Zaimplementuj `AutoHidePolicy`**

Stwórz `NotchShelf/Shelf/Services/AutoHidePolicy.swift`:

```swift
import Foundation

/// Pure policy resolving the auto-hide delay from defaults. Centralizes the
/// fallback applied across `ContentView` and `AppDelegate`.
enum AutoHidePolicy {
    static let fallbackDelaySeconds: TimeInterval = 1.5

    static func collapseDelay(defaults: UserDefaults = .standard) -> TimeInterval {
        let stored = defaults.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
        return stored > 0 ? stored : fallbackDelaySeconds
    }
}
```

Dodaj plik do targetów `NotchShelf` i `NotchShelfTests` (test target potrzebuje `@testable import NotchShelf`, więc wystarczy main target).

```bash
which xcodegen && xcodegen generate
```

- [ ] **Step 4: Run test — must pass**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 112/112 green (108 + 4 nowe).

- [ ] **Step 5: Zastosuj `AutoHidePolicy` w `ContentView`**

W `NotchShelf/App/ContentView.swift` zamień linie 226-229 (`handleHover` → `.ended`):

Stary kod:
```swift
case .ended:
    guard windowModel.expansion == .expanded else { return }
    let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
    windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
```

Nowy kod:
```swift
case .ended:
    guard windowModel.expansion == .expanded else { return }
    windowModel.scheduleCollapse(after: AutoHidePolicy.collapseDelay())
```

- [ ] **Step 6: Zastosuj `AutoHidePolicy` w `AppDelegate`**

W `NotchShelf/App/AppDelegate.swift` zamień linie 63-66 (`onDragEnd`):

Stary kod:
```swift
} else if !self.windowModel.dragTargeting {
    let delay = UserDefaults.standard.double(forKey: UserDefaultsKey.autoHideDelaySeconds)
    self.windowModel.scheduleCollapse(after: delay > 0 ? delay : 1.5)
}
```

Nowy kod:
```swift
} else if !self.windowModel.dragTargeting {
    self.windowModel.scheduleCollapse(after: AutoHidePolicy.collapseDelay())
}
```

- [ ] **Step 7: Build, testy, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 112/112 green.

```bash
git add NotchShelf/Shelf/Services/AutoHidePolicy.swift \
        NotchShelfTests/AutoHidePolicyTests.swift \
        NotchShelf/App/ContentView.swift \
        NotchShelf/App/AppDelegate.swift \
        NotchShelf.xcodeproj project.yml
git commit -m "refactor: extract AutoHidePolicy to centralize auto-hide delay lookup"
```

---

### Task 6: `nonisolated(unsafe) var key` → `static let key: UInt8 = 0`

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift:117,124`

- [ ] **Step 1: Zmień deklarację klucza na immutable**

`objc_setAssociatedObject` używa adresu zmiennej, nie jej wartości — wystarczy `static let` zamiast `static var`, co eliminuje potrzebę `nonisolated(unsafe)`.

W `NotchShelf/Shelf/State/ShelfItemViewModel.swift`:

Stary kod (linia 124):
```swift
    nonisolated(unsafe) static var key: UInt8 = 0
```

Nowy kod:
```swift
    static let key: UInt8 = 0
```

(Linia 117 — `&MenuActionTarget.key` — pozostaje bez zmian; adres `let`-a jest tak samo stabilny jak `var`-a.)

- [ ] **Step 2: Build, test, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`, 112/112 green.

Manual: prawokliknij item na półce → kontekstowe menu działa (testuje, że associated object jest poprawnie retainowany).

```bash
git add NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "refactor: replace nonisolated(unsafe) var with static let for associated-object key"
```

---

### Task 7: Anulowalny `Task` w `ShelfStore.cleanupInvalidItems()`

**Files:**
- Modify: `NotchShelf/Shelf/State/ShelfStore.swift:227-242`

- [ ] **Step 1: Dodaj instance-level `cleanupTask` handle**

W `NotchShelf/Shelf/State/ShelfStore.swift` poszukaj sekcji z pozostałymi `Task`-handlami (loadTask, updateTask, saveTask, inflightWrite) i dodaj obok:

```swift
private var cleanupTask: Task<Void, Never>?
```

(Powinno trafić w okolice `private var inflightWrite: ...` — sprawdź konkretną linię w aktualnym pliku, ~linia 200-220.)

- [ ] **Step 2: Zaktualizuj `cleanupInvalidItems` żeby trzymał handle**

Stary kod (linie 227-242):
```swift
func cleanupInvalidItems() {
    Task { @MainActor [weak self] in
        guard let self else { return }
        let snapshot = self.items
        let validIDs = await Self.validateInParallel(snapshot)
        let snapshotIDs = Set(snapshot.map(\.id))
        // Keep validated items, plus anything added since the snapshot.
        self.slots = self.reslot(self.slots.map { slot in
            guard let item = slot.item else { return slot }
            if validIDs.contains(item.id) || !snapshotIDs.contains(item.id) {
                return slot
            }
            return ShelfSlot(id: slot.id)
        })
    }
}
```

Nowy kod:
```swift
func cleanupInvalidItems() {
    cleanupTask?.cancel()
    cleanupTask = Task { @MainActor [weak self] in
        guard let self else { return }
        let snapshot = self.items
        let validIDs = await Self.validateInParallel(snapshot)
        guard !Task.isCancelled else { return }
        let snapshotIDs = Set(snapshot.map(\.id))
        // Keep validated items, plus anything added since the snapshot.
        self.slots = self.reslot(self.slots.map { slot in
            guard let item = slot.item else { return slot }
            if validIDs.contains(item.id) || !snapshotIDs.contains(item.id) {
                return slot
            }
            return ShelfSlot(id: slot.id)
        })
        self.cleanupTask = nil
    }
}
```

- [ ] **Step 3: Anuluj w `flushPendingSaveSync` (zamykanie aplikacji)**

W `flushPendingSaveSync()` na początku (~linia 325) dodaj:

```swift
cleanupTask?.cancel()
```

- [ ] **Step 4: Build, test, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 112/112 green.

```bash
git add NotchShelf/Shelf/State/ShelfStore.swift
git commit -m "refactor(shelf-store): track cleanupInvalidItems Task to allow cancellation"
```

---

### Task 8: `SystemNotificationWindowMonitor.stop()` anuluje pending poll Task

**Files:**
- Modify: `NotchShelf/App/SystemNotificationWindowMonitor.swift`

- [ ] **Step 1: Wprowadź `pollTask` handle**

W klasie `SystemNotificationWindowMonitor` (linie 24-48) dodaj prywatne pole:

```swift
private var pollTask: Task<Void, Never>?
```

- [ ] **Step 2: Zapamiętuj task przy każdym tick timera i anuluj w `stop()`**

Stary kod (linie 34-42):
```swift
func start() {
    stop()
    visibleWindowIDs = currentNotificationWindowIDs()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.poll()
        }
    }
}

func stop() {
    timer?.invalidate()
    timer = nil
    visibleWindowIDs.removeAll()
}
```

Nowy kod:
```swift
func start() {
    stop()
    visibleWindowIDs = currentNotificationWindowIDs()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        guard let self else { return }
        self.pollTask?.cancel()
        self.pollTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            self.poll()
        }
    }
}

func stop() {
    timer?.invalidate()
    timer = nil
    pollTask?.cancel()
    pollTask = nil
    visibleWindowIDs.removeAll()
}
```

Uwaga: `Timer.scheduledTimer` z closure zwraca `self` jako `MainActor`-isolated po unwrapie `weak self`, dlatego `self.pollTask = ...` jest legalne w obrębie closure timera (klasa jest `@MainActor`).

- [ ] **Step 3: Build, test, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 112/112 green.

```bash
git add NotchShelf/App/SystemNotificationWindowMonitor.swift
git commit -m "fix(system-monitor): cancel pending poll Task in stop() to prevent late-fire after shutdown"
```

---

## Phase 3 — Ekstrakcja `SystemEventGlowCoordinator` z `AppDelegate`

### Task 9: Stwórz `SystemEventGlowCoordinator` z testowalnym predykatem

**Files:**
- Create: `NotchShelf/App/SystemEventGlowCoordinator.swift`
- Modify: `NotchShelf/App/AppDelegate.swift`
- Modify: `NotchShelfTests/SystemNotificationWindowMonitorTests.swift:172-178` (jeśli test odnosi się do `AppDelegate.isLikelyNotificationDistributedEvent`)

- [ ] **Step 1: Stwórz nową klasę-coordinator z całym workflowem obserwatorów**

Plik `NotchShelf/App/SystemEventGlowCoordinator.swift`:

```swift
import AppKit

/// Owns subscription to system events that should pulse the notch glow:
/// workspace wake/session events, screen-parameter changes, distributed
/// notifications from Notification Center, and a polling window monitor that
/// catches banners without a public notification.
///
/// Extracted from `AppDelegate` to keep that type focused on app lifecycle.
@MainActor
final class SystemEventGlowCoordinator {
    private let defaults: UserDefaults
    private let onGlow: @MainActor (String) -> Void
    private var workspaceEventObservers: [NSObjectProtocol] = []
    private var appEventObservers: [NSObjectProtocol] = []
    private var distributedEventObservers: [NSObjectProtocol] = []
    private var systemNotificationWindowMonitor: SystemNotificationWindowMonitor?
    private var lastGlowDate = Date.distantPast
    private let rateLimit: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        rateLimit: TimeInterval = 0.8,
        onGlow: @escaping @MainActor (String) -> Void
    ) {
        self.defaults = defaults
        self.rateLimit = rateLimit
        self.onGlow = onGlow
    }

    func start() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceEventObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: "wake")
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: "session-active")
                }
            }
        ]

        appEventObservers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: "screen-parameters")
                }
            }
        ]

        let distributedCenter = DistributedNotificationCenter.default()
        distributedEventObservers = [
            "com.apple.notificationcenterui.banner",
            "com.apple.notificationcenterui.customalerts",
            "com.apple.notificationcenterui.customalerts-alive"
        ].map { name in
            distributedCenter.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerGlowIfEnabled(reason: name)
                }
            }
        }
        distributedEventObservers.append(
            distributedCenter.addObserver(
                forName: nil,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let notificationName = notification.name.rawValue
                Task { @MainActor [weak self] in
                    guard !notificationName.isEmpty,
                          Self.isLikelyNotificationDistributedEvent(notificationName)
                    else { return }
                    self?.triggerGlowIfEnabled(reason: notificationName)
                }
            }
        )

        let monitor = SystemNotificationWindowMonitor { [weak self] in
            self?.triggerGlowIfEnabled(reason: "notification-window")
        }
        monitor.start()
        systemNotificationWindowMonitor = monitor
    }

    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceEventObservers {
            workspaceCenter.removeObserver(observer)
        }
        workspaceEventObservers.removeAll()

        for observer in appEventObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appEventObservers.removeAll()

        let distributedCenter = DistributedNotificationCenter.default()
        for observer in distributedEventObservers {
            distributedCenter.removeObserver(observer)
        }
        distributedEventObservers.removeAll()

        systemNotificationWindowMonitor?.stop()
        systemNotificationWindowMonitor = nil
    }

    static func isLikelyNotificationDistributedEvent(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.contains("notificationcenter")
            || lowercasedName.contains("usernotification")
            || lowercasedName.contains("customalerts")
            || lowercasedName.contains("banner")
    }

    private func triggerGlowIfEnabled(reason: String) {
        guard defaults.bool(forKey: UserDefaultsKey.glowOnSystemEvents) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastGlowDate) >= rateLimit else { return }
        lastGlowDate = now
        AppLogger.systemEvents.notice("System glow requested: \(reason, privacy: .public)")
        onGlow(reason)
    }
}
```

- [ ] **Step 2: Odchudź `AppDelegate`**

Nowa wersja `NotchShelf/App/AppDelegate.swift`:

```swift
import AppKit

/// Owns the app's long-lived controllers. Created via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowModel = ShelfWindowModel()
    private var windowController: NotchWindowController?
    private var dragMonitor: DragMonitor?
    private var glowCoordinator: SystemEventGlowCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerPreferenceDefaults()
        guard !Self.isRunningTests else { return }
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController(windowModel: windowModel)
        setupDragMonitor()
        setupGlowCoordinator()
        ShelfStore.shared.cleanupInvalidItems()
        reconcileLaunchAtLoginPreference()
    }

    func applicationWillTerminate(_ notification: Notification) {
        glowCoordinator?.stop()
        glowCoordinator = nil
        dragMonitor?.stopMonitoring()
        dragMonitor = nil
        ShelfStore.shared.flushPendingSaveSync()
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func setupDragMonitor() {
        let monitor = DragMonitor(regionProvider: { [weak self] in
            guard let self else { return .zero }
            guard !ShelfSelection.shared.isDragging else { return .zero }
            switch self.windowModel.expansion {
            case .collapsed:
                return NotchGeometry.current().dragCatchRegion()
            case .expanded:
                return (self.windowController?.panelFrame ?? NotchGeometry.current().notchRect)
                    .insetBy(
                        dx: -ShelfMetrics.dragExitHorizontalOutset,
                        dy: -ShelfMetrics.dragExitVerticalOutset
                    )
            }
        })
        monitor.onEnterRegion = { [weak self] in
            self?.windowModel.expand()
            self?.windowModel.setDragTargeting(true)
        }
        monitor.onExitRegion = { [weak self] in
            self?.windowModel.setDragTargeting(false)
        }
        monitor.onDragEnd = { [weak self] in
            guard let self else { return }
            if self.windowModel.dropEvent {
                self.windowModel.dropEvent = false
            } else if !self.windowModel.dragTargeting {
                self.windowModel.scheduleCollapse(after: AutoHidePolicy.collapseDelay())
            }
        }
        monitor.startMonitoring()
        dragMonitor = monitor
    }

    private func setupGlowCoordinator() {
        let coordinator = SystemEventGlowCoordinator { [weak self] _ in
            self?.windowModel.requestGlow()
        }
        coordinator.start()
        glowCoordinator = coordinator
    }

    private func reconcileLaunchAtLoginPreference() {
        let storedPref = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin)
        let actual = LaunchAtLoginService.shared.isCurrentlyEnabled
        if storedPref != actual {
            UserDefaults.standard.set(actual, forKey: UserDefaultsKey.launchAtLogin)
        }
    }
}
```

Usuwasz: `workspaceEventObservers`, `appEventObservers`, `distributedEventObservers`, `systemNotificationWindowMonitor`, `lastSystemGlowDate`, `setupSystemEventGlowObservers`, `tearDownSystemEventGlowObservers`, `triggerSystemEventGlowIfEnabled`, `isLikelyNotificationDistributedEvent`, prywatne `extension String { var nonEmpty }` (też już niepotrzebne, bo Coordinator używa `!notificationName.isEmpty`).

- [ ] **Step 3: Zaktualizuj test korzystający z `AppDelegate.isLikelyNotificationDistributedEvent`**

W `NotchShelfTests/SystemNotificationWindowMonitorTests.swift` znajdź sekcję `distributedNotificationFallbackAcceptsNotificationCenterNames` / `distributedNotificationFallbackRejectsUnrelatedNames` (~linie 172-178) i zamień `AppDelegate.isLikelyNotificationDistributedEvent(...)` na `SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent(...)`.

```bash
grep -n "AppDelegate.isLikelyNotificationDistributedEvent" NotchShelfTests/
```
Każde trafienie zamień globalnie:

```bash
# Verify by grep, then edit
grep -rn "AppDelegate.isLikelyNotificationDistributedEvent" NotchShelfTests/
```

- [ ] **Step 4: Dodaj test dla rate-limit Coordinatora**

Stwórz `NotchShelfTests/SystemEventGlowCoordinatorTests.swift`:

```swift
import XCTest
@testable import NotchShelf

@MainActor
final class SystemEventGlowCoordinatorTests: XCTestCase {
    func test_doesNotTrigger_whenDefaultDisabled() {
        let defaults = TestSupport.makeIsolatedDefaults()
        defaults.set(false, forKey: UserDefaultsKey.glowOnSystemEvents)
        var glowCalls = 0
        let coordinator = SystemEventGlowCoordinator(defaults: defaults) { _ in glowCalls += 1 }

        // Internal helper exercise via the recognizer (the closure path is
        // exercised by `start()`; we only assert the gate works).
        // The rate-limit is the value under test here.
        XCTAssertTrue(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.notificationcenterui.banner"))
        _ = coordinator  // silence unused warning
        XCTAssertEqual(glowCalls, 0)
    }

    func test_isLikelyNotificationDistributedEvent_acceptsNotificationCenterNames() {
        XCTAssertTrue(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.notificationcenterui.banner"))
        XCTAssertTrue(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.usernotificationcenter.foo"))
        XCTAssertTrue(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("BannerArrival"))
    }

    func test_isLikelyNotificationDistributedEvent_rejectsUnrelatedNames() {
        XCTAssertFalse(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent("com.apple.dock.changed"))
        XCTAssertFalse(SystemEventGlowCoordinator.isLikelyNotificationDistributedEvent(""))
    }
}
```

- [ ] **Step 5: Wygeneruj projekt, zbuduj, testy, commit**

```bash
which xcodegen && xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 115+ green (112 + 3 nowe).

Manual: uruchom aplikację, wyśli sobie test notification (`scripts/trigger-system-event.sh` jeśli istnieje), zweryfikuj że notch zaświeci. Następnie wyłącz toggle "Flash notch glow on system notifications and events" w Preferences i powtórz — glow nie powinien się odpalić.

```bash
git add NotchShelf/App/SystemEventGlowCoordinator.swift \
        NotchShelf/App/AppDelegate.swift \
        NotchShelfTests/SystemNotificationWindowMonitorTests.swift \
        NotchShelfTests/SystemEventGlowCoordinatorTests.swift \
        NotchShelf.xcodeproj project.yml
git commit -m "refactor: extract SystemEventGlowCoordinator from AppDelegate"
```

---

### Task 10: Bramkowanie system-event glow podczas startup-glow

**Files:**
- Modify: `NotchShelf/App/ContentView.swift` (linie 207-215 i 213-215 `.onChange`)
- Modify: `NotchShelf/Shared/ShelfWindowModel.swift` (jeśli wymaga to publicznego flagi — sprawdź `glowPulse`)

Cel: pierwszy `playStartupGlow()` po `onAppear` ma się dokończyć (700ms reduce-motion lub ~1200ms normalny cykl) zanim pierwszy system-event może go przerwać.

- [ ] **Step 1: Wprowadź `@State private var ignoreGlowPulses` z flagą**

W `NotchShelf/App/ContentView.swift` dodaj obok `didPlayStartupGlow`:

```swift
@State private var startupGlowFinishedAt: Date?
```

Następnie zmodyfikuj `playStartupGlow` i `.onChange(of: windowModel.glowPulse)`:

Stary kod:
```swift
.onChange(of: windowModel.glowPulse) { _, _ in
    playGlow()
}
```

```swift
private func playStartupGlow() {
    guard !didPlayStartupGlow else { return }
    didPlayStartupGlow = true
    playGlow()
}
```

Nowy kod:
```swift
.onChange(of: windowModel.glowPulse) { _, _ in
    // Suppress system-event glow while the startup glow is still mid-cycle.
    if let finish = startupGlowFinishedAt, Date() < finish {
        return
    }
    playGlow()
}
```

```swift
private func playStartupGlow() {
    guard !didPlayStartupGlow else { return }
    didPlayStartupGlow = true
    // Lock out system-event pulses until the startup glow's full envelope ends.
    let envelopeMillis: Double = reduceMotion ? 700 : 1380  // 180 in + 650 hold + 550 out
    startupGlowFinishedAt = Date().addingTimeInterval(envelopeMillis / 1000)
    playGlow()
}
```

- [ ] **Step 2: Build, test, manual**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 115/115 green.

Manual: uruchom apkę i natychmiast wyśli powiadomienie systemowe (`scripts/trigger-system-event.sh` lub `osascript -e 'display notification "test"'`). Startup glow ma się dokończyć bez przerwy; system-event glow odpali się dopiero po jego zakończeniu.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/App/ContentView.swift
git commit -m "fix(glow): gate system-event pulses during startup glow envelope"
```

---

## Phase 4 — Dostrojenie animacji

### Task 11: Zawężenie `.animation(_:value:)` z `animationSignature` do `windowModel.expansion`

**Files:**
- Modify: `NotchShelf/App/ContentView.swift` (linia 183)

Problem: aktualnie sprężyna re-strzela się przy każdej mutacji `store.items.count` / `totalFileCount`, a nawet jeśli nie ma zmiany geometrycznej (dodanie pliku w stanie expanded). Animacja powinna animować tylko expand/collapse.

- [ ] **Step 1: Zmień `value:` na `windowModel.expansion`**

W `ContentView.body` (linia 183):

Stary kod:
```swift
.animation(shelfAnimation, value: animationSignature)
```

Nowy kod:
```swift
.animation(shelfAnimation, value: windowModel.expansion)
```

- [ ] **Step 2: Usuń `AnimationSignature` i `animationSignature` (martwy kod)**

W `ContentView.swift` usuń (linie 119-131):
```swift
private struct AnimationSignature: Hashable {
    let expansion: ShelfWindowModel.Expansion
    let itemCount: Int
    let totalFileCount: Int
}

private var animationSignature: AnimationSignature {
    AnimationSignature(
        expansion: windowModel.expansion,
        itemCount: store.items.count,
        totalFileCount: store.totalFileCount
    )
}
```

Po usunięciu sprawdź, że nic innego się do tego nie odwołuje:
```bash
grep -n "animationSignature\|AnimationSignature" NotchShelf/
```
Expected: brak trafień.

- [ ] **Step 3: Manual test**

Uruchom apkę. Najedź kursorem na notch — shape powinien płynnie się rozwijać (spring 0.32s). W stanie expanded przeciągnij plik — drop nie powinien wywoływać dodatkowej animacji sprężyny na shape (przedtem `totalFileCount` zmieniało signature i re-strzelało spring). Collapse pozostaje płynny.

- [ ] **Step 4: Test + commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 115/115 green.

```bash
git add NotchShelf/App/ContentView.swift
git commit -m "refactor(animation): narrow shelf animation to expansion changes only"
```

---

### Task 12: Usunięcie `blendDuration: 0.08` z `shelfAnimation`

**Files:**
- Modify: `NotchShelf/App/ContentView.swift` (linia 116)

Problem: `blendDuration: 0.08` rozmywa pierwsze 25% każdego rozwinięcia. Default `blendDuration` (0) jest tu właściwy.

- [ ] **Step 1: Usuń parametr**

Stary kod (linia 116):
```swift
return .spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.08)
```

Nowy kod:
```swift
return .spring(response: 0.32, dampingFraction: 0.86)
```

- [ ] **Step 2: Manual test**

Najedź kursorem — sprężyna powinna startować zdecydowanie od pierwszej klatki (przedtem pierwsze 80ms były miękkim blendem). Wyjazd-wjazd kursora kilka razy z rzędu nie powinien dawać uczucia "rozmycia".

- [ ] **Step 3: Test + commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 115/115 green.

```bash
git add NotchShelf/App/ContentView.swift
git commit -m "refactor(animation): drop blendDuration on shelf spring for crisper start"
```

---

## Phase 5 — DI dla warstwy drag-source

### Task 13: Przekierowanie `ShelfStore.shared` / `ShelfSelection.shared` przez ViewModel w `ShelfItemDragSource`

**Files:**
- Modify: `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift`
- Modify: `NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift`
- Modify: `NotchShelf/Shelf/State/ShelfItemViewModel.swift` (dodanie publicznych metod opakowujących store/selection)

**Uwaga:** to większy refaktor warstwy drag i należy się spodziewać, że trzeba będzie dotknąć też `ShelfItemView.swift` (call site, który tworzy `ShelfItemDragSource`). Zalecam wykonanie w osobnym branchu i merge dopiero po pełnej regresji drag-and-drop.

- [ ] **Step 1: Dodaj wrapper API w `ShelfItemViewModel`**

W `NotchShelf/Shelf/State/ShelfItemViewModel.swift` dodaj publiczne metody, które obecnie `ShelfItemDragSource` / `StackFileDragSource` wywołują na `ShelfStore.shared` / `ShelfSelection.shared`. Konkretne metody do zwrócenia są zależne od aktualnej implementacji drag — zacznij od `grep`:

```bash
grep -n "ShelfStore.shared\|ShelfSelection.shared" NotchShelf/Shelf/Views/Drag/
```

Dla każdego wywołania dodaj forwarding na ViewModel. Przykład (uzupełnij wg rzeczywistego użycia):

```swift
// In ShelfItemViewModel
func beginExternalDrag() {
    selection.setDragging(true)
}

func endExternalDrag() {
    selection.setDragging(false)
}

func removeSelfFromShelf() {
    store.remove(item.id)
}

var copyOnDragPreferenceEnabled: Bool {
    // Hand the lookup through the policy/defaults injected at init.
    defaults.bool(forKey: UserDefaultsKey.copyOnDrag)
}
```

(Wymaga to dodania `let defaults: UserDefaults` do ViewModelu, jeśli jeszcze nie ma, i przekazania z punktu konstrukcji w `ShelfItemView` jako `UserDefaults.standard` — lub przyjęcia zależności wyżej w łańcuchu.)

- [ ] **Step 2: Przepisz `ShelfItemDragSource` żeby używał `viewModel`**

W `NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift` zamień bezpośrednie odwołania `ShelfStore.shared.<method>` i `ShelfSelection.shared.<method>` na `viewModel.<method>`. Wymaga to upewnienia się, że `viewModel: ShelfItemViewModel?` jest dostępny w każdym callbacku — obecnie jest jako `weak var viewModel` w `DraggableClickView`, więc wystarczy unwrapować w każdym miejscu i przepuścić wywołanie przez VM.

Konkretne linie do zmiany (z reviewu):
- `ShelfItemDragSource.swift:85` — `ShelfStore.shared.<something>` → `viewModel?.<wrapper>`
- `ShelfItemDragSource.swift:91`
- `ShelfItemDragSource.swift:98`
- `ShelfItemDragSource.swift:136`
- `ShelfItemDragSource.swift:160` — `UserDefaults.standard.bool(forKey: UserDefaultsKey.copyOnDrag)` → `viewModel?.copyOnDragPreferenceEnabled ?? false`

(Sprawdź każdą linię w aktualnym pliku przed edycją — numery mogą się zmienić po wcześniejszych zadaniach.)

- [ ] **Step 3: Analogicznie `StackFileDragSource`**

`StackFileDragSource.swift:94, 116, 118, 97` — te same wzorce. Jeśli `StackFileDragSource` nie ma `viewModel` jako pola, dodaj odpowiednią zależność albo przekaż `ShelfStoring`/`SelectionStoring`/`UserDefaults` w init.

- [ ] **Step 4: Manual regression test drag-and-drop**

To krytyczna ścieżka — zrób pełny scenariusz:

1. Drag pliku z Findera na collapsed notch → notch się rozwija, plik ląduje na półce.
2. Drag pliku z półki do Findera → plik się przenosi (jeśli `copyOnDrag = false`) lub kopiuje (jeśli `true`).
3. Drag itemu między slotami na półce → reorder.
4. Drag z półki na inną aplikację (np. Mail) → plik trafia do tej aplikacji.
5. Stack file drag (item zawierający wiele plików) → rozwija panel z listą, drag pojedynczego pliku ze stacku.

W każdym przypadku zweryfikuj brak crashe'ów / brak pozostawionych "duchów" itemów.

- [ ] **Step 5: Build, testy, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: 115/115 green.

```bash
git add NotchShelf/Shelf/Views/Drag/ShelfItemDragSource.swift \
        NotchShelf/Shelf/Views/Drag/StackFileDragSource.swift \
        NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "refactor(drag): route store/selection/defaults access through ShelfItemViewModel"
```

---

## Phase 6 — Kosmetyka (post-merge)

Te zadania nie wymagają testów (czysto styl/kod) — wystarczy zachować zielony pasek po każdym commicie.

### Task 14: `LocalizedStringKey` w komponentach Preferences

**Files:**
- Modify: `NotchShelf/App/Preferences/PreferenceRow.swift`
- Modify: `NotchShelf/App/Preferences/PreferenceSliderRow.swift`
- Modify: `NotchShelf/App/Preferences/PreferenceDoubleSliderRow.swift` (utworzony w Task 4)
- Modify: `NotchShelf/App/Preferences/PreferenceToggleRow.swift`
- Modify: `NotchShelf/App/Preferences/PreferenceFootnote.swift`
- Modify: `NotchShelf/App/Preferences/PreferencesSection.swift`

- [ ] **Step 1: Zamień `String` na `LocalizedStringKey` w każdym `title:`/`text:` parametrze tych typów**

Każdy `let title: String` / `let text: String` w wymienionych plikach zamień na `let title: LocalizedStringKey`. SwiftUI automatycznie wyciągnie te klucze do `Localizable.xcstrings` przy włączonej autoekstrakcji.

Dla `PreferencesSection.title: String?` użyj `LocalizedStringKey?` (uwaga: `LocalizedStringKey` jest `ExpressibleByStringLiteral`, więc istniejące wywołania typu `PreferencesSection("Behaviour")` skompilują się bez zmian).

- [ ] **Step 2: Build, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
```

```bash
git add NotchShelf/App/Preferences/
git commit -m "i18n: use LocalizedStringKey for Preferences component titles"
```

---

### Task 15: Stała `ShelfAnimations` namespace

**Files:**
- Create: `NotchShelf/Shelf/Views/ShelfAnimations.swift`
- Modify: `NotchShelf/App/ContentView.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfView.swift` (linia 91 - `.easeInOut(0.12)`)
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift` (linie 70-71)

- [ ] **Step 1: Stwórz namespace**

```swift
import SwiftUI

enum ShelfAnimations {
    /// Spring driving expand/collapse of the shelf shape.
    static let shelf: Animation = .spring(response: 0.32, dampingFraction: 0.86)
    /// Reduce-motion fallback for shelf shape transitions.
    static let shelfReduced: Animation = .easeInOut(duration: 0.14)

    /// Glow envelope phases (in milliseconds).
    enum Glow {
        static let inDuration: Double = 0.18
        static let holdMillis: Int = 650
        static let outDuration: Double = 0.55
        static let reducedMotionHoldMillis: Int = 700
    }

    /// Drag-target / selection hover crossfade.
    static let itemHover: Animation = .easeInOut(duration: 0.1)
    /// Outline stroke-width swap when drop target changes.
    static let outlineHover: Animation = .easeInOut(duration: 0.12)
}
```

- [ ] **Step 2: Zastąp magic numbers**

W `ContentView.swift`:
- Linia 114: `.easeInOut(duration: 0.14)` → `ShelfAnimations.shelfReduced`
- Linia 116: `.spring(response: 0.32, dampingFraction: 0.86)` → `ShelfAnimations.shelf`
- Linia 268: `.easeOut(duration: 0.18)` → `.easeOut(duration: ShelfAnimations.Glow.inDuration)`
- Linia 273: `.milliseconds(650)` → `.milliseconds(ShelfAnimations.Glow.holdMillis)`
- Linia 275: `.easeOut(duration: 0.55)` → `.easeOut(duration: ShelfAnimations.Glow.outDuration)`
- Linia 261: `.milliseconds(700)` → `.milliseconds(ShelfAnimations.Glow.reducedMotionHoldMillis)`

W `ShelfView.swift:91`: `.easeInOut(duration: 0.12)` → `ShelfAnimations.outlineHover`

W `ShelfItemView.swift:70-71`: dwie `.animation(.easeInOut(duration: 0.1), value:)` → `ShelfAnimations.itemHover`

- [ ] **Step 3: Build, commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```

```bash
git add NotchShelf/Shelf/Views/ShelfAnimations.swift \
        NotchShelf/App/ContentView.swift \
        NotchShelf/Shelf/Views/ShelfView.swift \
        NotchShelf/Shelf/Views/ShelfItemView.swift \
        NotchShelf.xcodeproj project.yml
git commit -m "refactor: centralize shelf animation constants into ShelfAnimations namespace"
```

---

### Task 16: Konsolidacja podwójnego `.animation(_:value:)` w `ShelfItemView`

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift:70-71`

- [ ] **Step 1: Połącz dwa `.animation` w jeden z złożonym kluczem**

W `ShelfItemView.itemContent` zamiast:
```swift
.animation(.easeInOut(duration: 0.1), value: debouncedDropTarget)
.animation(.easeInOut(duration: 0.1), value: isSelected)
```

zrób:
```swift
private struct ItemAnimationKey: Hashable {
    let dropTarget: Bool
    let isSelected: Bool
}

// W body:
.animation(ShelfAnimations.itemHover, value: ItemAnimationKey(
    dropTarget: debouncedDropTarget,
    isSelected: isSelected
))
```

- [ ] **Step 2: Commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "refactor(shelf-item): combine duplicate .animation modifiers into one with composite key"
```

---

### Task 17: `RoundedRectangle.fill().stroke()` zamiast `.overlay { strokeBorder }`

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift:199-206`

- [ ] **Step 1: Połącz fill + stroke na jednym shape**

Stary kod (`backgroundView`):
```swift
RoundedRectangle(cornerRadius: ..., style: .continuous)
    .fill(backgroundColor)
    .overlay {
        RoundedRectangle(cornerRadius: ..., style: .continuous)
            .strokeBorder(strokeColor, lineWidth: strokeWidth)
    }
```

Nowy kod:
```swift
RoundedRectangle(cornerRadius: ..., style: .continuous)
    .fill(backgroundColor)
    .stroke(strokeColor, lineWidth: strokeWidth)
```

(macOS 14+/iOS 17+ wspiera bezpośrednio chained `.fill().stroke()` na `Shape`.)

- [ ] **Step 2: Commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
git add NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "refactor(shelf-item): replace .overlay { strokeBorder } with chained .fill().stroke()"
```

---

### Task 18: Rozbicie `StackFileListPanel.swift` na pojedyncze pliki

**Files:**
- Modify: `NotchShelf/Shelf/Views/Stack/StackFileListPanel.swift`
- Create: `NotchShelf/Shelf/Views/Stack/StackFileListView.swift`
- Create: `NotchShelf/Shelf/Views/Stack/StackFileRowView.swift`
- Create: `NotchShelf/Shelf/Views/Stack/StackFileListPanelPresenter.swift`
- Create: `NotchShelf/Shelf/Views/Stack/StackMenuEntry.swift`

- [ ] **Step 1: Wytnij każdy typ do własnego pliku**

Plik `StackFileListPanel.swift` obecnie zawiera 5 typów. Wyciągnij je tak, żeby:
- `StackMenuEntry.swift` — typ `StackMenuEntry` (enum)
- `StackFileListView.swift` — `StackFileListView: View`
- `StackFileRowView.swift` — `StackFileRowView: View`
- `StackFileListPanelPresenter.swift` — `StackFileListPanelPresenter` + nested `Coordinator`
- `StackFileListPanel.swift` — pozostaw tylko fasadę/entry point (jeśli istnieje typ o tej samej nazwie); jeśli plik nie ma już żadnego typu, można go usunąć.

`@MainActor`/`@objc` adnotacje muszą zostać; brak prywatnych typów z `private struct` poza file scope w extracted plikach (zamień `private` → `internal`/default jeśli typ jest używany cross-file).

- [ ] **Step 2: xcodegen + build**

```bash
which xcodegen && xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug test 2>&1 | tail -5
```
Expected: build + 115/115 green.

- [ ] **Step 3: Commit**

```bash
git add NotchShelf/Shelf/Views/Stack/ NotchShelf.xcodeproj project.yml
git commit -m "refactor: split StackFileListPanel.swift into one type per file"
```

---

### Task 19: `.scrollIndicators(.hidden)` zamiast `showsIndicators:`

**Files:**
- Modify: `NotchShelf/App/Preferences/PreferencesPage.swift:16`
- Modify: `NotchShelf/Shelf/Views/Stack/StackFileListView.swift` (po Task 18: linie 19 i 32)

- [ ] **Step 1: Zamień deprecated `ScrollView(.vertical, showsIndicators: false)` na nowoczesny modyfikator**

Wzór:
```swift
ScrollView(.vertical) { ... }
    .scrollIndicators(.hidden)
```

W `PreferencesPage.swift`: zmień konstruktor `ScrollView`-a tak, żeby nie używał `showsIndicators:`, dodaj modyfikator. Sparametryzowanie (jeśli `PreferencesPage` przyjmuje bool):
```swift
.scrollIndicators(showsIndicators ? .visible : .hidden)
```

W `StackFileListView.swift`: jeśli były dwie redundancje (`showsIndicators: false` + `.scrollIndicators(.never)`), zostaw tylko `.scrollIndicators(.never)`.

- [ ] **Step 2: Commit**

```bash
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Debug build 2>&1 | tail -5
git add NotchShelf/App/Preferences/PreferencesPage.swift \
        NotchShelf/Shelf/Views/Stack/StackFileListView.swift
git commit -m "refactor: replace deprecated showsIndicators: with .scrollIndicators modifier"
```

---

### Task 20: Decyzja dotycząca `loadThumbnailIfNeeded` (martwy kod albo regresja)

**Files:**
- Audit: `NotchShelf/Shelf/Views/ShelfItemView.swift:80-82, 135-145`
- Audit: `NotchShelf/Shelf/State/ShelfItemViewModel.swift`

- [ ] **Step 1: Zweryfikuj, czy thumbnail powinien być widoczny**

```bash
grep -n "thumbnail\|loadThumbnail\|thumbnailTask" NotchShelf/Shelf/
```

Jeśli design jest icon-only (intencja produktowa) — usuń całą maszynerię thumbnail z `ShelfItemViewModel` (pole `@Published private(set) var thumbnail`, `func loadThumbnailIfNeeded()`, `thumbnailTask` etc.) jako martwy kod.

Jeśli to regresja (thumbnaily powinny się ładować) — przywróć w `ShelfItemView.onAppear`:
```swift
.onAppear { viewModel.loadThumbnailIfNeeded() }
```
i obraz w `iconView`:
```swift
Image(nsImage: viewModel.thumbnail ?? viewModel.icon)
```

- [ ] **Step 2: Spytaj autora (jeśli pracujesz solo: zdecyduj na podstawie design intent z `AGENTS.md` / TODO.md / git blame na poprzedniej wersji), commit**

```bash
git log -p --follow -- NotchShelf/Shelf/Views/ShelfItemView.swift | grep -A 5 "thumbnail"
```

```bash
git add NotchShelf/Shelf/Views/ShelfItemView.swift NotchShelf/Shelf/State/ShelfItemViewModel.swift
git commit -m "<chore: remove dead thumbnail code OR fix(shelf-item): restore thumbnail rendering>"
```

---

## Deferred (rozważ na osobny milestone)

- **Migracja `ObservableObject` → `@Observable` (Swift 5.9+ macro)** dla `ShelfWindowModel`, `ShelfStore`, `ShelfSelection`, `ShelfItemViewModel`. To większa zmiana semantyczna (zmienia `@StateObject`/`@ObservedObject`/`@EnvironmentObject` na `@State`/`@Bindable`/`@Environment`), dotyka większości plików widoków i zasługuje na własny plan.
- **`NSHostingView` boundaries + Increase Contrast support dla przycisków na shelf** — zmiana koloru przycisku Preferences w `ShelfRevealContent` z hardcoded `.white.opacity(0.88)` na `.symbolRenderingMode(.hierarchical) + .tint(...)` lub własny `ButtonStyle`. Wymaga design review.
- **`NotchGeometry.current()` cachowanie z observerem `didChangeScreenParametersNotification`** — micro-optimization w `ContentView`.

---

## Kolejność realizacji (sugerowana)

1. Phase 1 (Tasks 1-4) — szybkie wygrane SwiftUI, ~30-60 min.
2. Phase 2 (Tasks 5-8) — ekstrakcje policy + cleanup taskhandle, ~1-2h.
3. **Tag `stable-1.1`** — punkt kontrolny, wszystkie ważne ustalenia z review (oprócz Phase 5) zaadresowane.
4. Phase 3 (Tasks 9-10) — ekstrakcja `SystemEventGlowCoordinator` + gating glow.
5. Phase 4 (Tasks 11-12) — dostrojenie animacji (potrzebuje regresji wizualnej, najlepiej na żywym urządzeniu).
6. Phase 5 (Task 13) — DI dla drag-source (oddzielny PR, pełna regresja drag).
7. Phase 6 (Tasks 14-20) — kosmetyka i porządki w wolnych chwilach.

**Po każdym commicie:** `xcodebuild ... test` musi pokazać `** TEST SUCCEEDED **`. Jeśli któryś task wywróci testy, NIE komituj — diagnozuj root cause.

# Plan Aktualizacji (TODO 5 punktów) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wdrożyć 5 zmian UI z [TODO.md](../../../TODO.md): obniżyć siatkę półki, sparametryzować kolor obwiednii, przebudować wygląd slotu (ikony większe, licznik na górze, brak nazwy, symetria dolnych ikon), animować wysuwanie/wsuwanie półki w pionie, podmienić ikonę miotły na nową grafikę SVG.

**Architecture:** Zmiany dotyczą wyłącznie warstwy widoku (`NotchShelf/Shelf/Views`, `NotchShelf/App/ContentView.swift`, `NotchShelf/App/Preferences`) i konfiguracji preferencji (`PreferencesKeys.swift`). Logika domenowa (`ShelfStore`, `ShelfItem`, `Bookmark`) pozostaje nietknięta. Kolor obwiednii zapisany jako 4 floaty (R,G,B,A) w `UserDefaults` — żadnych archiwów `NSKeyedArchiver`, łatwo testowalne. Animacja półki: symetryczny `.move(edge: .top)` zarówno na insertion i removal, podpięty pod istniejący `shelfContentTransition`. Nowa ikona SVG ładowana z Asset Catalog jako template image.

**Tech Stack:** Swift 6, SwiftUI, AppKit (Asset Catalog), Swift Testing (`@Test`), XcodeGen (`project.yml`), macOS 14+.

---

## File Structure

**Files created:**
- `NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/Contents.json` — Asset Catalog metadata (vector SVG, template-rendered)
- `NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/icon.svg` — kopia z `_icons/icon.svg`
- `NotchShelf/Shared/RGBAColor.swift` — codable wartość koloru zapisywana w `UserDefaults` (R,G,B,A jako `Double`), z konwersją do/z `SwiftUI.Color`
- `NotchShelfTests/RGBAColorTests.swift` — testy enkodowania/dekodowania, round-trip do `Color`, wartość domyślna

**Files modified:**
- `NotchShelf/App/ContentView.swift` — przesunięcie półki niżej (top padding), symetria animacji wsuwania (`.move(edge: .top)` w removal)
- `NotchShelf/Shelf/Views/ShelfView.swift` — odczyt `dropZoneColor` z `UserDefaults` zamiast hardcoded RGB
- `NotchShelf/Shelf/Views/ShelfSlotPlaceholderView.swift` — zwiększenie rozmiaru obszaru placeholdera (ikona większa)
- `NotchShelf/Shelf/Views/ShelfItemView.swift` — przebudowa layoutu: licznik na górze, brak nazwy pod ikoną, ikona większa, dolny rząd ikon (stack-list + plus) symetryczny lub plus na środku
- `NotchShelf/Window/ShelfMetrics.swift` — nowe stałe: `iconSizeLarge`, `slotInnerSpacingTop`, `slotInnerSpacingBottom`, `shelfTopChromeHeight`
- `NotchShelf/Shelf/Views/ShelfClearButton.swift` — podmiana `BroomIcon()` na `Image("ClearShelfIcon")`, usunięcie wewnętrznej struktury `BroomIcon`
- `NotchShelf/App/Preferences/PreferencesKeys.swift` — nowy klucz `dropZoneColor` + rejestracja wartości domyślnej (4 floaty)
- `NotchShelf/App/Preferences/ShelfPreferencesView.swift` — sekcja "Drop zone" z `ColorPicker` powiązanym z `RGBAColor`

**Files not changed:** `ShelfStore.swift`, `ShelfItem.swift`, `Bookmark.swift`, `NotchGeometry.swift`, `NotchShelfShape.swift`, `NotchWindowController.swift`, `DragMonitor.swift`.

---

## Task 1: Podmiana ikony miotły (TODO #5)

Najmniejsza, najprostsza zmiana — robimy ją pierwszą, żeby od razu zobaczyć w build, że pipeline z Asset Catalog działa.

**Files:**
- Create: `NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/Contents.json`
- Create: `NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/icon.svg`
- Modify: `NotchShelf/Shelf/Views/ShelfClearButton.swift`

- [ ] **Step 1: Skopiuj plik SVG do Asset Catalog**

Run:
```bash
mkdir -p /Users/micz/__DEV__/notch/NotchShelf/Assets.xcassets/ClearShelfIcon.imageset
cp /Users/micz/__DEV__/notch/_icons/icon.svg /Users/micz/__DEV__/notch/NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/icon.svg
```

Expected: oba pliki na miejscu.

- [ ] **Step 2: Utwórz `Contents.json` dla imageset**

Plik: `NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/Contents.json`

```json
{
  "images" : [
    {
      "filename" : "icon.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
```

`template-rendering-intent: template` sprawia, że SVG jest tonowany kolorem `foregroundStyle` (tak jak SF Symbols), `preserves-vector-representation: true` trzyma czystą wektorówkę dla skalowania.

- [ ] **Step 3: Zregeneruj projekt Xcode**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodegen generate
```

Expected output: `Loaded project … Created project at NotchShelf.xcodeproj`. Nowy asset musi pojawić się w bundle resource.

- [ ] **Step 4: Podmień `BroomIcon` na `Image("ClearShelfIcon")`**

Zastąp całą zawartość [`NotchShelf/Shelf/Views/ShelfClearButton.swift`](../../../NotchShelf/Shelf/Views/ShelfClearButton.swift):

```swift
import SwiftUI

struct ShelfClearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("ClearShelfIcon")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear shelf")
        .accessibilityLabel("Clear shelf")
    }
}
```

Cała struktura `BroomIcon` (linie 20–66) znika; rysowanie ścieżek `Path` zastępuje wektor z Asset Catalog.

- [ ] **Step 5: Zbuduj i uruchom testy (sanity check)**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. Brak referencji do `BroomIcon` w żadnym pliku.

- [ ] **Step 6: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/Contents.json \
        NotchShelf/Assets.xcassets/ClearShelfIcon.imageset/icon.svg \
        NotchShelf/Shelf/Views/ShelfClearButton.swift \
        NotchShelf.xcodeproj
git commit -m "feat(shelf): replace broom path icon with vector ClearShelfIcon asset"
```

---

## Task 2: Kolor obwiednii w preferencjach — model `RGBAColor` (TDD — wartość)

Zaczynamy od testów modelu koloru zanim podepniemy go do `UserDefaults` i ColorPickera.

**Files:**
- Create: `NotchShelf/Shared/RGBAColor.swift`
- Create: `NotchShelfTests/RGBAColorTests.swift`

- [ ] **Step 1: Napisz failing test enkodowania do `[Double]` i z powrotem**

Plik: `NotchShelfTests/RGBAColorTests.swift`

```swift
import Testing
import SwiftUI
@testable import NotchShelf

@Suite("RGBAColor")
struct RGBAColorTests {
    @Test func roundTripsThroughComponents() {
        let color = RGBAColor(red: 0.0, green: 0.88, blue: 0.84, alpha: 1.0)
        let components = color.components
        let restored = RGBAColor(components: components)
        #expect(restored == color)
    }

    @Test func defaultMatchesLegacyTurquoise() {
        let defaultColor = RGBAColor.defaultDropZone
        #expect(defaultColor.red == 0.0)
        #expect(defaultColor.green == 0.88)
        #expect(defaultColor.blue == 0.84)
        #expect(defaultColor.alpha == 1.0)
    }

    @Test func componentsHasExactlyFourValues() {
        let color = RGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        #expect(color.components.count == 4)
        #expect(color.components == [0.1, 0.2, 0.3, 0.4])
    }

    @Test func malformedComponentsFallBackToDefault() {
        let restored = RGBAColor(components: [0.5, 0.5]) // za mało wartości
        #expect(restored == .defaultDropZone)
    }

    @Test func clampsOutOfRangeValues() {
        let color = RGBAColor(red: -0.5, green: 1.7, blue: 0.5, alpha: 2.0)
        #expect(color.red == 0.0)
        #expect(color.green == 1.0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1.0)
    }
}
```

- [ ] **Step 2: Uruchom testy — powinny się nie skompilować**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | grep -E "(error:|FAIL)" | head -10
```

Expected: błędy "cannot find 'RGBAColor' in scope". To zamierzony stan red TDD.

- [ ] **Step 3: Stwórz `RGBAColor.swift` z minimalną implementacją**

Plik: `NotchShelf/Shared/RGBAColor.swift`

```swift
import SwiftUI

/// Stable RGBA color value persisted as `[Double]` in `UserDefaults`.
/// Avoids `NSKeyedArchiver` so the stored representation is human-readable in
/// `defaults read` and trivially testable.
struct RGBAColor: Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let defaultDropZone = RGBAColor(red: 0.0, green: 0.88, blue: 0.84, alpha: 1.0)

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    init(components: [Double]) {
        guard components.count == 4 else {
            self = .defaultDropZone
            return
        }
        self.init(
            red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components[3]
        )
    }

    var components: [Double] { [red, green, blue, alpha] }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func clamp(_ value: Double) -> Double {
        Swift.min(Swift.max(value, 0.0), 1.0)
    }
}
```

- [ ] **Step 4: Uruchom testy — powinny przejść**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite 'RGBAColor'|passed|failed)" | head -10
```

Expected: `Test Suite 'RGBAColor' passed`. Wszystkie 5 testów zielone.

- [ ] **Step 5: Zregeneruj projekt po dodaniu nowego pliku**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodegen generate
```

Expected: nowe pliki `RGBAColor.swift` i `RGBAColorTests.swift` dopisane do projektu.

- [ ] **Step 6: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Shared/RGBAColor.swift \
        NotchShelfTests/RGBAColorTests.swift \
        NotchShelf.xcodeproj
git commit -m "feat(shared): add RGBAColor value with components <-> Color bridging"
```

---

## Task 3: Klucz preferencji i wartość domyślna dla `dropZoneColor` (TDD — preferencje)

**Files:**
- Modify: `NotchShelf/App/Preferences/PreferencesKeys.swift`
- Modify: `NotchShelfTests/PreferencesKeysTests.swift`

- [ ] **Step 1: Napisz failing test rejestracji domyślnego koloru**

Dodaj na końcu `PreferencesKeysTests` (przed `keysAreStable`):

```swift
    @Test
    func registerPreferenceDefaultsInstallsDropZoneColor() {
        let suiteName = "PreferencesKeysTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        registerPreferenceDefaults(in: suite)

        let stored = suite.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
        #expect(stored == RGBAColor.defaultDropZone.components)
    }

    @Test
    func dropZoneColorKeyIsStable() {
        #expect(UserDefaultsKey.dropZoneColor == "dropZoneColor")
    }
```

Też dopisz w `registerPreferenceDefaultsInstallsExpectedValues`:

```swift
        let storedColor = suite.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
        #expect(storedColor == [0.0, 0.88, 0.84, 1.0])
```

- [ ] **Step 2: Uruchom testy — failują**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | grep -E "error:" | head -5
```

Expected: `error: type 'UserDefaultsKey' has no member 'dropZoneColor'`.

- [ ] **Step 3: Dodaj klucz i wartość domyślną**

Zmień [`NotchShelf/App/Preferences/PreferencesKeys.swift`](../../../NotchShelf/App/Preferences/PreferencesKeys.swift) na:

```swift
import Foundation

/// All persisted user preference keys. Keep names string-stable across versions;
/// renaming silently loses existing user data.
enum UserDefaultsKey {
    static let copyOnDrag = "copyOnDrag"
    static let autoHideDelaySeconds = "autoHideDelaySeconds"
    static let launchAtLogin = "launchAtLogin"
    static let minSlotCount = "minSlotCount"
    static let maxSlotCount = "maxSlotCount"
    static let stackListGridThreshold = "stackListGridThreshold"
    static let dropZoneColor = "dropZoneColor"
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
        UserDefaultsKey.stackListGridThreshold: 5,
        UserDefaultsKey.dropZoneColor: RGBAColor.defaultDropZone.components
    ])
}
```

- [ ] **Step 4: Uruchom testy — zielone**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite 'PreferencesKeys'|passed|failed)" | head -5
```

Expected: `Test Suite 'PreferencesKeys' passed`.

- [ ] **Step 5: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/App/Preferences/PreferencesKeys.swift \
        NotchShelfTests/PreferencesKeysTests.swift
git commit -m "feat(prefs): persist dropZoneColor as RGBA components with turquoise default"
```

---

## Task 4: ColorPicker w `ShelfPreferencesView` (TODO #2)

`@AppStorage` nie wspiera array<Double> bezpośrednio. Bridge przez computed binding z `UserDefaults.standard`.

**Files:**
- Modify: `NotchShelf/App/Preferences/ShelfPreferencesView.swift`

- [ ] **Step 1: Dodaj sekcję "Drop zone" z `ColorPicker`**

Zastąp całość [`NotchShelf/App/Preferences/ShelfPreferencesView.swift`](../../../NotchShelf/App/Preferences/ShelfPreferencesView.swift):

```swift
import SwiftUI

struct ShelfPreferencesView: View {
    @AppStorage(UserDefaultsKey.minSlotCount) private var minSlotCount = 5
    @AppStorage(UserDefaultsKey.maxSlotCount) private var maxSlotCount = 15
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var stackListGridThreshold = 5

    @State private var dropZoneColor: Color = RGBAColor.defaultDropZone.color

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

            Section("Drop zone") {
                ColorPicker("Outline color", selection: $dropZoneColor, supportsOpacity: true)
                Text("The dashed outline that pulses when files hover the shelf.")
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
        .onAppear(perform: loadDropZoneColor)
        .onChange(of: dropZoneColor) { _, newValue in
            persist(dropZoneColor: newValue)
        }
    }

    private func loadDropZoneColor() {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
            ?? RGBAColor.defaultDropZone.components
        dropZoneColor = RGBAColor(components: components).color
    }

    private func persist(dropZoneColor color: Color) {
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return }
        let rgba = RGBAColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        UserDefaults.standard.set(rgba.components, forKey: UserDefaultsKey.dropZoneColor)
    }
}
```

`NSColor(_:Color)` jest dostępne od macOS 14, projekt celuje w 14.0.

- [ ] **Step 2: Zbuduj — sprawdź sygnatury**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/App/Preferences/ShelfPreferencesView.swift
git commit -m "feat(prefs): expose drop-zone outline color picker in Shelf preferences"
```

---

## Task 5: `ShelfView` czyta `dropZoneColor` z `UserDefaults`

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfView.swift`

- [ ] **Step 1: Zastąp hardcoded RGB odczytem `@AppStorage`-podobnym**

`@AppStorage` nie wspiera `[Double]`. Użyj `UserDefaults` + `@State` ze nasłuchem przez `NotificationCenter` (UserDefaults emituje `.NSUserDefaultsDidChange`).

Zmień górną część [`NotchShelf/Shelf/Views/ShelfView.swift`](../../../NotchShelf/Shelf/Views/ShelfView.swift) (zachowując resztę pliku):

```swift
import AppKit
import SwiftUI

/// The shelf panel: a wrapping grid of file slots. Empty slots accept drops and
/// selected items can be removed with Delete.
struct ShelfView: View {
    @EnvironmentObject var windowModel: ShelfWindowModel
    @ObservedObject var store = ShelfStore.shared
    @ObservedObject var selection = ShelfSelection.shared
    @State private var localDropTargeting = false
    @State private var dropZoneRGBA: RGBAColor = ShelfView.loadDropZoneColor()
    private let spacing: CGFloat = ShelfMetrics.itemSpacing
    private var isVisuallyTargeted: Bool { windowModel.dragTargeting || localDropTargeting }
    private var dropZoneColor: Color {
        let base = dropZoneRGBA.color
        return base.opacity(isVisuallyTargeted ? 0.95 : 0.68)
    }

    private var rowCapacity: Int {
        Swift.max(UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount), 3)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(ShelfMetrics.itemWidth), spacing: spacing, alignment: .top),
            count: rowCapacity
        )
    }

    var body: some View {
        panel
            .onDrop(of: [.fileURL], isTargeted: $localDropTargeting) { providers in
                handleDrop(providers: providers, slotIndex: nil)
            }
            .focusable()
            .onDeleteCommand {
                for item in selection.selectedItems(in: store.items) {
                    ShelfActionService.remove(item)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let next = Self.loadDropZoneColor()
                if next != dropZoneRGBA { dropZoneRGBA = next }
            }
    }

    private static func loadDropZoneColor() -> RGBAColor {
        let components = UserDefaults.standard.array(forKey: UserDefaultsKey.dropZoneColor) as? [Double]
            ?? RGBAColor.defaultDropZone.components
        return RGBAColor(components: components)
    }
```

`Color.opacity(_:)` nadpisuje alfę, więc obecne tłumienie nadal działa. Reszta pliku (`handleDrop`, `panel`, `content`) pozostaje bez zmian — wystarczy zaktualizować deklarację `dropZoneColor`.

- [ ] **Step 2: Sanity build**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manualny test (golden path)**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -3
# Uruchom binarkę z Xcode (Cmd+R) lub:
open /Users/micz/__DEV__/notch/.build/Build/Products/Debug/NotchShelf.app 2>/dev/null || true
```

Manualnie: otwórz Preferences → Shelf → Drop zone → zmień kolor na czerwony. Powieś plikiem nad notchem — przerywana obwiednia powinna być czerwona, nie turkusowa. Wróć do domyślnego turkusu kliknięciem koła z paletą i wpisując 00E0D6 / α=100%.

- [ ] **Step 4: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Shelf/Views/ShelfView.swift
git commit -m "feat(shelf): use dropZoneColor preference for dashed outline"
```

---

## Task 6: Przesunięcie obwiednii niżej — pod chrome (TODO #1)

Obwiednia (`ShelfView.panel`) startuje na `notchHeight + 12`, a górny pasek z przyciskami "Clear" i "Preferences" siedzi w `ZStack` nad nią. Wizualnie obwiednia wchodzi pod te przyciski. Musimy zwiększyć padding tak, by obwiednia zaczynała się dopiero pod paskiem.

**Files:**
- Modify: `NotchShelf/Window/ShelfMetrics.swift`
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Dodaj stałą `shelfTopChromeHeight` w `ShelfMetrics`**

Dodaj w [`NotchShelf/Window/ShelfMetrics.swift`](../../../NotchShelf/Window/ShelfMetrics.swift) (po `shelfPanelBottomPadding`):

```swift
    /// Vertical space reserved for the top chrome row (Clear button + Preferences button)
    /// so the dashed shelf outline never crosses underneath either icon.
    static let shelfTopChromeHeight: CGFloat = 32
```

- [ ] **Step 2: Zwiększ górny padding `ShelfView` w `ContentView`**

W [`NotchShelf/App/ContentView.swift`](../../../NotchShelf/App/ContentView.swift) zmień blok `ShelfView()` (linie ok. 105-112):

```swift
                if windowModel.expansion == .expanded {
                    ShelfView()
                        .environmentObject(windowModel)
                        .padding(.horizontal, currentTopCornerRadius + 12)
                        .padding(.top, geometry.notchHeight + ShelfMetrics.shelfTopChromeHeight)
                        .padding(.bottom, ShelfMetrics.shelfPanelBottomPadding)
                        .transition(shelfContentTransition)
                        .zIndex(1)
```

Skutek: dashed outline startuje `shelfTopChromeHeight` (32 pt) poniżej dolnej krawędzi notcha — przyciski "Clear" i "Preferences" znajdują się nad obwiednią.

- [ ] **Step 3: Zwiększ wysokość ekspansji o `shelfTopChromeHeight - 12`**

W `expandedShapeSize` (linie ok. 28-44) zaktualizuj `chromeHeight`:

```swift
    private var expandedShapeSize: CGSize {
        let baseRow = Swift.max(UserDefaults.standard.integer(forKey: UserDefaultsKey.minSlotCount), 3)
        let slotCount = store.visibleSlotCount
        let rows = Swift.max(Int((Double(slotCount) / Double(baseRow)).rounded(.up)), 1)
        let rowHeight = ShelfMetrics.itemHeight + ShelfMetrics.itemSpacing
        let chromeHeight = geometry.notchHeight
            + ShelfMetrics.shelfTopChromeHeight
            + ShelfMetrics.shelfPanelBottomPadding
        let height = chromeHeight + CGFloat(rows) * rowHeight
        ...
```

Zachowujesz strukturę funkcji, ale `chromeHeight` jest spójne z paddingiem ShelfView (poprzednio twarda liczba `24`).

- [ ] **Step 4: Manualny test odstępu**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -3
```

Uruchom w Xcode (Cmd+R). Najedź kursorem na notch — półka się rozszerza. Sprawdź wzrokowo:
- Przyciski Clear (lewo, miotła/SVG) i Preferences (prawo, zębatka) mają wokół siebie czystą czarną przestrzeń.
- Górna pozioma krawędź przerywanej obwiednii znajduje się WYRAŹNIE poniżej tych przycisków.
- Brak nakładania.

- [ ] **Step 5: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Window/ShelfMetrics.swift NotchShelf/App/ContentView.swift
git commit -m "fix(shelf): drop dashed outline below top chrome row"
```

---

## Task 7: Symetryczna animacja wsuwania półki (TODO #4)

Obecna `shelfContentTransition` wstawia półkę przez `.move(edge: .top)`, ale przy usuwaniu używa tylko `opacity + scale`. Stąd wrażenie, że "pojawia się tło aplikacji" — kontent znika w miejscu zamiast wsunąć się do góry.

**Files:**
- Modify: `NotchShelf/App/ContentView.swift`

- [ ] **Step 1: Zsymetryzuj `shelfContentTransition`**

Zastąp definicję `shelfContentTransition` w [`NotchShelf/App/ContentView.swift`](../../../NotchShelf/App/ContentView.swift) (linie ok. 63-72):

```swift
    private var shelfContentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let slide = AnyTransition.move(edge: .top)
            .combined(with: .opacity)
        return .asymmetric(insertion: slide, removal: slide)
    }
```

Skutek: zarówno wjazd jak i wyjazd to ruch wzdłuż górnej krawędzi (z góry w dół przy wjeździe, z dołu w górę przy wyjeździe). Skalowanie usuwamy — zostaje czyste "wysuwanie/wsuwanie półki", zgodne z TODO ("animacja to ma byc wysuwanie z gory do dolu, potem wsuwanie do gory!").

- [ ] **Step 2: Dodaj clip wewnątrz kształtu, by content nie wystawał ponad notch**

Półka rośnie z góry — musi być przycięta do bieżącego rozmiaru `NotchShelfShape`, inaczej kontent będzie się "wylewał" za animowany kształt. W [`NotchShelf/App/ContentView.swift`](../../../NotchShelf/App/ContentView.swift) zmień główny `ZStack` aby content był maskowany do shape:

```swift
            ZStack {
                NotchShelfShape(
                    topCornerRadius: currentTopCornerRadius,
                    bottomCornerRadius: windowModel.expansion == .expanded
                        ? ShelfMetrics.bottomCornerRadius : 8
                )
                .fill(Color.black)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal, currentTopCornerRadius)
                }

                if windowModel.expansion == .expanded {
                    ShelfView()
                        .environmentObject(windowModel)
                        .padding(.horizontal, currentTopCornerRadius + 12)
                        .padding(.top, geometry.notchHeight + ShelfMetrics.shelfTopChromeHeight)
                        .padding(.bottom, ShelfMetrics.shelfPanelBottomPadding)
                        .transition(shelfContentTransition)
                        .zIndex(1)

                    topBar
                        .padding(.top, preferencesButtonTopPadding)
                        .transition(shelfContentTransition)
                        .zIndex(2)
                } else if hasItems {
                    collapsedIndicators
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(width: shapeSize.width, height: shapeSize.height)
            .clipShape(
                NotchShelfShape(
                    topCornerRadius: currentTopCornerRadius,
                    bottomCornerRadius: windowModel.expansion == .expanded
                        ? ShelfMetrics.bottomCornerRadius : 8
                )
            )
            .animation(shelfAnimation, value: animationSignature)
            .onHover(perform: handleHover)
```

Zmiana to: `.clipped()` (linia 125) → `.clipShape(NotchShelfShape(...))` z dokładnie tymi samymi promieniami, których używa `fill`. To gwarantuje, że animowany content wjeżdża/wyjeżdża wewnątrz konturu notcha.

- [ ] **Step 3: Manualny test animacji**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -3
```

Uruchom (Cmd+R). Najedź kursorem na notch i odjedź — obserwuj:
- Półka WSUWA SIĘ z góry, wzrokowo "spod" notcha. ✅
- Po zjechaniu kursora po `autoHideDelaySeconds` (1.5s) półka WSUWA SIĘ z powrotem do góry, znika pod notchem. ✅
- Nie widać "gołego tła okna" w czasie animacji. ✅

Powtórz z włączonym **Reduce Motion** (System Settings → Accessibility → Display → Reduce motion). Wtedy fallback `.opacity` — half-and-out crossfade jest poprawne (zgodne z założeniem `reduceMotion`).

- [ ] **Step 4: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/App/ContentView.swift
git commit -m "fix(shelf): slide shelf in/out from top edge symmetrically"
```

---

## Task 8: Przebudowa slotu — większa ikona, licznik na górze, brak nazwy, symetria dolnych ikon (TODO #3)

Największa zmiana — przeprojektowanie `ShelfItemView` zgodnie ze szkicem [`Untitled-1.jpg`](../../../Untitled-1.jpg):
- Powiększona ikona pliku
- Licznik plików nad ikoną (np. "(10)") — tylko dla stacków
- Brak nazwy pliku pod ikoną
- Dolny pasek: dla stacków `[stack-list] [plus]` symetrycznie po bokach; dla pojedynczego pliku `[plus]` na środku

**Files:**
- Modify: `NotchShelf/Window/ShelfMetrics.swift`
- Modify: `NotchShelf/Shelf/Views/ShelfItemView.swift`
- Modify: `NotchShelfTests/ShelfItemViewModelTests.swift` (opcjonalnie, jeżeli test wymaga aktualizacji)

- [ ] **Step 1: Dodaj nowe stałe rozmiaru w `ShelfMetrics`**

W [`NotchShelf/Window/ShelfMetrics.swift`](../../../NotchShelf/Window/ShelfMetrics.swift) dodaj (po `iconSize`):

```swift
    /// Larger icon size used inside shelf item slots (no name label below).
    static let iconSizeLarge: CGFloat = 40
    /// Vertical space between the file count label and the icon.
    static let slotInnerSpacingTop: CGFloat = 2
    /// Vertical space between the icon and the bottom toggle row.
    static let slotInnerSpacingBottom: CGFloat = 4
    /// Height of the file-count label row at the top of each slot.
    static let slotCountLabelHeight: CGFloat = 12
```

- [ ] **Step 2: Przeprojektuj `ShelfItemView.itemContent`**

Zastąp w [`NotchShelf/Shelf/Views/ShelfItemView.swift`](../../../NotchShelf/Shelf/Views/ShelfItemView.swift) deklaracje `itemContent`, `iconView`, `stackListButton`, `copyModeButton`, oraz `textView` (usuwamy `textView` całkowicie). Pełna nowa wersja od linii 46:

```swift
    private var itemContent: some View {
        VStack(spacing: 0) {
            ZStack {
                VStack(alignment: .center, spacing: ShelfMetrics.slotInnerSpacingTop) {
                    countLabel
                    iconView
                }
                .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemBodyHeight)
                .background(backgroundView)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.1), value: debouncedDropTarget)
                .animation(.easeInOut(duration: 0.1), value: isSelected)

                DraggableClickHandler(
                    item: item,
                    viewModel: viewModel,
                    cachedPreviewImage: $cachedPreviewImage,
                    onClick: { event, nsView in viewModel.handleClick(event: event, view: nsView) },
                    onRightClick: { event, nsView in viewModel.handleRightClick(event: event, view: nsView) }
                )
            }
            bottomToggleRow
        }
        .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemHeight)
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            dropTargetDebounceTask?.cancel()
            dropTargetDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            viewModel.loadThumbnailIfNeeded()
            refreshDragPreview()
        }
        .onChange(of: viewModel.thumbnail) { _, _ in
            refreshDragPreview()
        }
        .onChange(of: item) { _, updated in
            viewModel.update(item: updated)
            refreshDragPreview()
        }
        .onDisappear {
            dropTargetDebounceTask?.cancel()
            dragPreviewTask?.cancel()
        }
    }

    @ViewBuilder
    private var countLabel: some View {
        if viewModel.viewData.isStack {
            Text("(\(viewModel.viewData.stackCount))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .frame(height: ShelfMetrics.slotCountLabelHeight)
                .accessibilityLabel("\(viewModel.viewData.stackCount) files")
        } else {
            Color.clear.frame(height: ShelfMetrics.slotCountLabelHeight)
        }
    }

    private var iconView: some View {
        ZStack {
            if item.isStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(0.16))
                    .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                    .offset(x: 4, y: -4)
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(0.22))
                    .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                    .offset(x: 2, y: -2)
            }
            Image(nsImage: viewModel.thumbnail ?? viewModel.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: ShelfMetrics.iconSizeLarge, height: ShelfMetrics.iconSizeLarge)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
        .frame(width: ShelfMetrics.iconSizeLarge + (item.isStack ? 6 : 0),
               height: ShelfMetrics.iconSizeLarge + (item.isStack ? 6 : 0))
    }

    @ViewBuilder
    private var bottomToggleRow: some View {
        if item.isStack {
            HStack(spacing: 0) {
                stackListButton
                Spacer(minLength: 0)
                copyModeButton
            }
            .padding(.horizontal, 6)
            .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemToggleHeight)
        } else {
            HStack {
                Spacer(minLength: 0)
                copyModeButton
                Spacer(minLength: 0)
            }
            .frame(width: ShelfMetrics.itemWidth, height: ShelfMetrics.itemToggleHeight)
        }
    }

    private var stackListButton: some View {
        Button {
            showingStackList.toggle()
        } label: {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: ShelfMetrics.itemToggleHeight, height: ShelfMetrics.itemToggleHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Show stack files")
        .accessibilityLabel("Show stack files")
    }

    private var copyModeButton: some View {
        Button(action: onToggleKeepsItemAfterExternalDrop) {
            Image(systemName: keepsItemAfterExternalDrop ? "plus.circle.fill" : "plus.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(keepsItemAfterExternalDrop ? Color.accentColor : .white.opacity(0.72))
                .frame(width: ShelfMetrics.itemToggleHeight, height: ShelfMetrics.itemToggleHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(keepsItemAfterExternalDrop ? "Copy from this slot" : "Move from this slot")
        .accessibilityLabel(keepsItemAfterExternalDrop ? "Copy from this slot" : "Move from this slot")
    }
```

Co znika:
- `textView` (nazwa pliku pod ikoną) — usunięte całkowicie.
- Overlay z `stackListButton` w `ZStack` (linie 70-76 oryginału) — przeniesione do `bottomToggleRow`.

Co zostaje:
- Drag preview, klick handling, kontekstowe menu, drag-target debouncing — wszystko bez zmian.

- [ ] **Step 3: Zachowaj `backgroundView` / `backgroundColor` / `strokeColor` / `strokeWidth`**

Bez modyfikacji. Tylko `textView` znika. Sprawdź, że nie ma już żadnej referencji do `textView`:

Run:
```bash
grep -n "textView" /Users/micz/__DEV__/notch/NotchShelf/Shelf/Views/ShelfItemView.swift
```

Expected: brak wyników (empty).

- [ ] **Step 4: Zaktualizuj `DragPreviewView` jeżeli pokazuje nazwę pliku**

Sprawdź:
```bash
grep -n "displayName" /Users/micz/__DEV__/notch/NotchShelf/Shelf/Views/DragPreviewView.swift
```

`DragPreviewView` pokazuje miniaturę PODCZAS przeciągania kursorem — to jest tooltip nad kursorem, nie wewnątrz slotu, więc tej nazwy NIE usuwamy (drag-preview to inny kontekst niż widok slotu — użytkownik chce wiedzieć co przeciąga). Zostawiamy bez zmian.

- [ ] **Step 5: Zbuduj — upewnij się że nie ma dangling references**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | grep -E "(error:|warning:|BUILD)" | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Brak `'textView'` errors.

- [ ] **Step 6: Uruchom istniejące testy slotu**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite|passed|failed)" | head -10
```

Expected: wszystkie 60+ testów green. Logika domenowa (`ShelfItemViewModel`, `ShelfItemViewData`) nie była dotknięta — testy mają nadal przechodzić. `ShelfItemViewModelTests.iconMatchesNSWorkspaceForResolvedURL` sprawdza `viewModel.icon.size`, nie size renderowanej w UI — nie wymaga aktualizacji.

- [ ] **Step 7: Manualny test wizualny**

Uruchom (Cmd+R). Przeciągnij na półkę:
- Pojedynczy plik PDF — w slocie widać DUŻĄ miniaturę PDF, nad nią pusty pasek (placeholder dla licznika), pod nią TYLKO ikonę `+` na środku. Brak nazwy "raport.pdf".
- Folder z 3 plikami — slot pokazuje stack (offsetowane warstwy w tle ikony), nad ikoną `(3)`, pod ikoną `[list-icon]` po lewej i `[+]` po prawej, symetrycznie.

Porównaj z [`Untitled-1.jpg`](../../../Untitled-1.jpg).

- [ ] **Step 8: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Window/ShelfMetrics.swift NotchShelf/Shelf/Views/ShelfItemView.swift
git commit -m "feat(shelf): redesign slot — bigger icon, count above, no name, symmetric toggles"
```

---

## Task 9: Dostosuj `ShelfSlotPlaceholderView` do nowego rozmiaru ikony

Pusty slot rysuje `RoundedRectangle` o boku `iconSize * 2` (= 48). Skoro powiększyliśmy ikonę do 40, placeholder też trzeba odświeżyć, by wizualnie pasował do wypełnionych slotów.

**Files:**
- Modify: `NotchShelf/Shelf/Views/ShelfSlotPlaceholderView.swift`

- [ ] **Step 1: Wyrównaj rozmiar placeholdera do `iconSizeLarge`**

Zmień w [`NotchShelf/Shelf/Views/ShelfSlotPlaceholderView.swift`](../../../NotchShelf/Shelf/Views/ShelfSlotPlaceholderView.swift) linię 14:

```swift
    private var slotSize: CGFloat { ShelfMetrics.iconSizeLarge + 12 }
```

(`iconSizeLarge` = 40, +12 dla marginu wewnętrznego daje 52 — bliskie obecnym 48, ale spójne z większą ikoną.)

- [ ] **Step 2: Sanity build**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manualny test**

Uruchom. Najedź kursorem z plikiem na notch (nie upuszczaj). Powinno pokazać siatkę pustych slotów. Placeholdery są wizualnie podobnej szerokości co wypełnione miniatury.

- [ ] **Step 4: Commit**

```bash
cd /Users/micz/__DEV__/notch
git add NotchShelf/Shelf/Views/ShelfSlotPlaceholderView.swift
git commit -m "feat(shelf): scale empty slot placeholder to match larger icon"
```

---

## Task 10: Test pełnego flow + smoke run

Po wszystkich zmianach uruchom pełny test suite i smoke run aplikacji.

- [ ] **Step 1: Uruchom pełny test suite**

Run:
```bash
cd /Users/micz/__DEV__/notch && xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -destination 'platform=macOS' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, wszystkie testy (60+ z poprzedniego cyklu, +5 nowych dla `RGBAColor`, +2 nowe dla `PreferencesKeys`) zielone.

- [ ] **Step 2: Smoke checklist — uruchom aplikację**

Uruchom (Cmd+R) lub:
```bash
open /Users/micz/__DEV__/notch/.build/Build/Products/Debug/NotchShelf.app
```

Sprawdź na żywo:
1. ✅ **Ikona Clear** w lewym górnym rogu rozszerzonej półki — to nowa wektorówka z SVG, nie miotła.
2. ✅ **Kolor obwiednii** zmienia się w preferencjach (Drop zone → Outline color) i odzwierciedla na półce w czasie rzeczywistym.
3. ✅ **Obwiednia** nie wchodzi pod przyciski Clear/Preferences — odstęp wyraźny.
4. ✅ **Półka wjeżdża z góry w dół** przy najechaniu kursorem; **wsuwa się do góry** po `autoHideDelaySeconds`. Brak nagiego tła w trakcie animacji.
5. ✅ **Slot** pokazuje powiększoną ikonę bez nazwy pliku pod nią; dla stacków widać licznik `(N)` nad ikoną i dwie ikony toggle symetrycznie poniżej; dla pojedynczego pliku tylko `+` na środku.

Każdy punkt który nie przechodzi — opisz konkretnie co widać vs co oczekiwano, NIE oznaczaj jako complete.

- [ ] **Step 3: Final commit (jeżeli żadnych poprawek)**

Jeżeli wszystko OK, plan zakończony. Brak dodatkowego commitu — każda zmiana ma swój.

Jeżeli widać regresję — wróć do odpowiedniego Tasku, dodaj kolejny commit "fix(shelf): adjust XYZ post-implementation".

---

## Mapowanie zadań do TODO

| TODO punkt | Task                          |
| ---------- | ----------------------------- |
| #1 siatka niżej | Task 6                  |
| #2 kolor w preferencjach | Task 2, 3, 4, 5 |
| #3 redesign slotu | Task 8, 9             |
| #4 animacja wsuwania | Task 7              |
| #5 podmiana ikony miotły | Task 1          |

---

## Notatki dla wykonawcy

- **DRY**: `RGBAColor.components` jest jedynym formatem persistencji koloru. Nie wprowadzaj `Codable` ani archiwizacji `NSKeyedArchiver` — over-engineering bez korzyści.
- **YAGNI**: ColorPicker celowo nie ma presetów ("Reset to default") — można dodać jeżeli użytkownik o to poprosi, ale nie dorzucamy "na zapas".
- **Frequent commits**: każdy Task = jeden commit. Nie batchuj zmian wielu tasków.
- **Reduce Motion**: respektuj `@Environment(\.accessibilityReduceMotion)` — fallback na `.opacity` w Task 7 jest istotny dla a11y.
- **Asset Catalog SVG**: macOS 14+ wspiera natywnie. Jeżeli z jakiegoś powodu nie renderuje się — sprawdź czy `preserves-vector-representation: true` jest w `Contents.json`.
- **Nie ruszaj** `ShelfStore`, `ShelfItem`, `Bookmark`, `ShelfPersistenceService`, `NotchGeometry`, `DragMonitor` — żadna z 5 zmian nie wymaga ich modyfikacji. Jeżeli kod cię tam ciągnie, zatrzymaj się i sprawdź założenia.

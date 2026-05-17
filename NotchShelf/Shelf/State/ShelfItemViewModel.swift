import AppKit
import Foundation
import ObjectiveC
import SwiftUI

/// Per-item view model: thumbnail, icon, click handling, double-click open, and a
/// minimal context menu.
@MainActor
final class ShelfItemViewModel: ObservableObject {
    @Published private(set) var item: ShelfItem
    @Published private(set) var viewData: ShelfItemViewData
    @Published private(set) var icon: NSImage = NSWorkspace.shared.icon(for: .data)
    @Published var thumbnail: NSImage?
    @Published var isDropTargeted: Bool = false

    private let store: ShelfStoring
    private let selection: SelectionStoring
    private let defaults: UserDefaults
    private var thumbnailTask: Task<Void, Never>?

    init(
        item: ShelfItem,
        store: ShelfStoring = ShelfStore.shared,
        selection: SelectionStoring = ShelfSelection.shared,
        defaults: UserDefaults = .standard
    ) {
        self.item = item
        self.viewData = ShelfItemViewData.build(from: item)
        self.icon = Self.icon(for: item)
        self.store = store
        self.selection = selection
        self.defaults = defaults
    }

    func update(item: ShelfItem) {
        guard self.item != item else { return }
        self.item = item
        self.viewData = ShelfItemViewData.build(from: item)
        self.icon = Self.icon(for: item)
        thumbnail = nil
    }

    var isSelected: Bool { selection.isSelected(item.id) }

    private static func icon(for item: ShelfItem) -> NSImage {
        if let url = item.fileURL {
            return url.accessSecurityScopedResource {
                NSWorkspace.shared.icon(forFile: $0.path)
            }
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    func loadThumbnailIfNeeded() {
        guard thumbnail == nil, thumbnailTask == nil else { return }
        loadThumbnail()
    }

    func loadThumbnail() {
        thumbnailTask?.cancel()
        guard let url = item.fileURL else {
            thumbnailTask = nil
            return
        }
        let itemID = item.id
        thumbnailTask = Task { @MainActor [weak self] in
            let image = await ThumbnailService.shared.thumbnail(
                for: url, size: CGSize(width: 56, height: 56)
            )
            guard !Task.isCancelled else { return }
            guard let self, self.item.id == itemID else { return }
            self.thumbnail = image
        }
    }

    deinit {
        thumbnailTask?.cancel()
    }

    func handleClick(event: NSEvent, view: NSView) {
        let flags = event.modifierFlags
        if flags.contains(.shift) {
            selection.shiftSelect(to: item, in: store.items)
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
        for selectedItem in selection.selectedItems(in: store.items) {
            ShelfActionService.open(selectedItem)
        }
    }

    func handleRightClick(event: NSEvent, view: NSView) {
        if !selection.isSelected(item.id) { selection.selectSingle(item) }
        let menu = NSMenu()
        addItem(to: menu, title: "Open") { ShelfActionService.open(self.item) }
        addItem(to: menu, title: "Show in Finder") { ShelfActionService.reveal(self.item) }
        addItem(to: menu, title: "Copy Path") { ShelfActionService.copyPath(self.item) }
        menu.addItem(.separator())
        addItem(to: menu, title: "Remove from Shelf") {
            for selectedItem in self.selection.selectedItems(in: self.store.items) {
                ShelfActionService.remove(selectedItem)
            }
        }
        menu.popUp(positioning: nil, at: event.locationInWindow, in: view)
    }

    func dragItems(containing item: ShelfItem) -> [ShelfItem] {
        let selected = selection.selectedItems(in: store.items)
        return (selected.count > 1 && selected.contains { $0.id == item.id }) ? selected : [item]
    }

    func keepsItemAfterExternalDrop(_ item: ShelfItem) -> Bool {
        store.keepsItemAfterExternalDrop(item)
    }

    func resolveFileURLs(for item: ShelfItem) -> [URL] {
        store.resolveFileURLs(for: item)
    }

    func removeFromShelf(_ item: ShelfItem) {
        store.remove(item)
    }

    func removeFromStack(bookmarkData: Data, from item: ShelfItem) {
        store.remove(bookmarkData: bookmarkData, from: item)
    }

    func clearSelection() {
        selection.clear()
    }

    func beginExternalDrag() {
        selection.beginDrag()
    }

    func endExternalDrag() {
        selection.endDrag()
    }

    var copyOnDragPreferenceEnabled: Bool {
        defaults.bool(forKey: UserDefaultsKey.copyOnDrag)
    }

    private func addItem(to menu: NSMenu, title: String, action: @escaping () -> Void) {
        let target = MenuActionTarget(action: action)
        let menuItem = NSMenuItem(title: title, action: #selector(MenuActionTarget.fire), keyEquivalent: "")
        menuItem.target = target
        withUnsafePointer(to: MenuActionTarget.key) { key in
            objc_setAssociatedObject(menuItem, key, target, .OBJC_ASSOCIATION_RETAIN)
        }
        menu.addItem(menuItem)
    }
}

/// Bridges a closure to an `@objc` selector for `NSMenuItem`.
private final class MenuActionTarget: NSObject {
    static let key: UInt8 = 0

    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func fire() {
        action()
    }
}

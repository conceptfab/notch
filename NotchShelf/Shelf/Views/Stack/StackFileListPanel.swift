import AppKit
import SwiftUI

struct StackMenuEntry {
    let id: Int
    let title: String
    let bookmarkData: Data
    let fileURL: URL?
}

struct StackFileListView: View {
    let item: ShelfItem
    @AppStorage(UserDefaultsKey.stackListGridThreshold) private var gridThreshold = 5
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

struct StackFileRowView: View {
    let sourceItem: ShelfItem
    let entry: StackMenuEntry
    @State private var icon: NSImage = NSWorkspace.shared.icon(for: .data)

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(entry.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
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

struct StackFileListPanelPresenter: NSViewRepresentable {
    let item: ShelfItem
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(item: item, anchoredTo: nsView, isPresented: isPresented)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.close()
    }

    @MainActor
    final class Coordinator {
        private let isPresented: Binding<Bool>
        private var panel: NSPanel?
        private var localMonitor: Any?
        private var globalMonitor: Any?

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func update(item: ShelfItem, anchoredTo anchorView: NSView, isPresented: Bool) {
            guard isPresented else {
                animateClose()
                return
            }

            let panel = panel ?? makePanel()
            self.panel = panel
            panel.contentViewController = makeContentController(for: item)
            let targetFrame = computeFrame(anchorView: anchorView, itemCount: item.allBookmarkData.count)

            if !panel.isVisible {
                let collapsedFrame = NSRect(
                    x: targetFrame.origin.x,
                    y: targetFrame.maxY,
                    width: targetFrame.size.width,
                    height: 0
                )
                panel.setFrame(collapsedFrame, display: false)
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrame(targetFrame, display: true)
                }
                installOutsideClickMonitor(anchorView: anchorView)
            } else {
                panel.setFrame(targetFrame, display: true)
            }
        }

        func animateClose() {
            guard let panel, panel.isVisible else {
                close()
                return
            }
            removeOutsideClickMonitors()
            let currentFrame = panel.frame
            let collapsedFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.maxY,
                width: currentFrame.size.width,
                height: 0
            )
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(collapsedFrame, display: true)
            }, completionHandler: { [weak self] in
                self?.close()
            })
        }

        func close() {
            panel?.orderOut(nil)
            panel = nil
            removeOutsideClickMonitors()
        }

        private func removeOutsideClickMonitors() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
        }

        private func makePanel() -> NSPanel {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            return panel
        }

        private func makeContentController(for item: ShelfItem) -> NSHostingController<some View> {
            let size = Self.targetSize(forItemCount: item.allBookmarkData.count)
            let view = StackFileListView(item: item)
                .frame(width: size.width, height: size.height)
                .background(Color.clear)
            let controller = NSHostingController(rootView: view)
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.clear.cgColor
            return controller
        }

        private func computeFrame(anchorView: NSView, itemCount: Int) -> NSRect {
            let size = Self.targetSize(forItemCount: itemCount)
            guard let window = anchorView.window else {
                return NSRect(origin: .zero, size: size)
            }
            let anchorRect = anchorView.convert(anchorView.bounds, to: nil)
            let screenRect = window.convertToScreen(anchorRect)
            let x = screenRect.midX - size.width / 2
            let y = screenRect.minY - size.height - 4
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }

        private static func targetSize(forItemCount itemCount: Int) -> NSSize {
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
            return NSSize(width: width, height: height)
        }

        private func installOutsideClickMonitor(anchorView: NSView) {
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak anchorView] event in
                guard let self else { return event }
                if event.window === self.panel {
                    return event
                }
                if let anchorView, event.window === anchorView.window {
                    let point = anchorView.convert(event.locationInWindow, from: nil)
                    if anchorView.bounds.contains(point) { return event }
                }
                self.isPresented.wrappedValue = false
                self.animateClose()
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.isPresented.wrappedValue = false
                    self?.animateClose()
                }
            }
        }
    }
}

import Foundation
import Testing
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
    model.expand()
    try? await Task.sleep(for: .seconds(0.15))
    #expect(model.expansion == .expanded)
}

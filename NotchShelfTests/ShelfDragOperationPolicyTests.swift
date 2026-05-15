import AppKit
import Testing
@testable import NotchShelf

@Test func shelfDragOperationPolicyUsesCopyOnlyWhenPreferenceIsEnabled() {
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: true,
            context: .outsideApplication
        ) == [.copy]
    )
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: true,
            context: .withinApplication
        ) == [.copy]
    )
}

@Test func shelfDragOperationPolicyAllowsMoveWhenPreferenceIsDisabled() {
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: false,
            context: .outsideApplication
        ) == [.copy]
    )
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: false,
            context: .withinApplication
        ) == [.copy, .move, .generic]
    )
}

@Test func shelfDragOperationPolicyRemovesOnlyAfterMove() {
    #expect(ShelfDragOperationPolicy.shouldRemoveFromShelf(after: .move))
    #expect(!ShelfDragOperationPolicy.shouldRemoveFromShelf(after: .copy))
    #expect(!ShelfDragOperationPolicy.shouldRemoveFromShelf(after: []))
}

@Test func outsideApplicationAlwaysReturnsCopyOnly() {
    let copyOnly = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .outsideApplication
    )
    #expect(copyOnly == [.copy])
}

@Test func outsideApplicationIgnoresCopyOnDragPreference() {
    let copyOn = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: true,
        context: .outsideApplication
    )
    #expect(copyOn == [.copy])
}

@Test func withinApplicationKeepsMoveByDefault() {
    let mask = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .withinApplication
    )
    #expect(mask.contains(.move))
}

import AppKit
import Testing
@testable import NotchShelf

@Test func shelfDragOperationPolicyUsesCopyOnlyWithinAppWhenPreferenceIsEnabled() {
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: true,
            context: .outsideApplication
        ) == [.copy, .move]
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
        ) == [.copy, .move]
    )
    #expect(
        ShelfDragOperationPolicy.sourceOperationMask(
            copyOnDrag: false,
            context: .withinApplication
        ) == [.copy, .move, .generic]
    )
}

@Test func shelfDragOperationPolicyRemovesOnlyAfterMoveWithinApplication() {
    #expect(ShelfDragOperationPolicy.shouldRemoveFromShelf(after: .move))
    #expect(!ShelfDragOperationPolicy.shouldRemoveFromShelf(after: .copy))
    #expect(!ShelfDragOperationPolicy.shouldRemoveFromShelf(after: []))
}

@Test func outsideApplicationCopyRemovesShelfEntryAfterSuccessfulDrop() {
    #expect(
        ShelfDragOperationPolicy.shouldRemoveFromShelf(
            after: .copy,
            context: .outsideApplication
        )
    )
}

@Test func outsideApplicationCopyKeepsShelfEntryWhenSlotCopyModeIsEnabled() {
    #expect(
        !ShelfDragOperationPolicy.shouldRemoveFromShelf(
            after: .copy,
            context: .outsideApplication,
            keepAfterExternalDrop: true
        )
    )
}

@Test func withinApplicationCopyKeepsShelfEntry() {
    #expect(
        !ShelfDragOperationPolicy.shouldRemoveFromShelf(
            after: .copy,
            context: .withinApplication
        )
    )
}

@Test func outsideApplicationAllowsFinderMoveByDefault() {
    let moveCapable = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .outsideApplication
    )
    #expect(moveCapable == [.copy, .move])
}

@Test func outsideApplicationIgnoresCopyOnDragPreference() {
    let copyOn = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: true,
        context: .outsideApplication
    )
    #expect(copyOn == [.copy, .move])
}

@Test func outsideApplicationCopyModeReturnsCopyOnly() {
    let copyOnly = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .outsideApplication,
        keepAfterExternalDrop: true
    )
    #expect(copyOnly == [.copy])
}

@Test func outsideApplicationMoveRemovesShelfEntryAfterSuccessfulDrop() {
    #expect(
        ShelfDragOperationPolicy.shouldRemoveFromShelf(
            after: .move,
            context: .outsideApplication
        )
    )
}

@Test func outsideApplicationMoveKeepsShelfEntryWhenSlotCopyModeIsEnabled() {
    #expect(
        !ShelfDragOperationPolicy.shouldRemoveFromShelf(
            after: .move,
            context: .outsideApplication,
            keepAfterExternalDrop: true
        )
    )
}

@Test func withinApplicationKeepsMoveByDefault() {
    let mask = ShelfDragOperationPolicy.sourceOperationMask(
        copyOnDrag: false,
        context: .withinApplication
    )
    #expect(mask.contains(.move))
}

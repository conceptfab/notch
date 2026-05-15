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
        ) == [.copy, .move]
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

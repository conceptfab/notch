import Foundation
import Testing
@testable import NotchShelf

@Suite("SlotCountPolicy")
struct SlotCountPolicyTests {
    @Test
    func returnsMinimumWhenNoItems() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 0,
            currentVisible: 5,
            baseSlotCount: 5,
            maxAdditionalRows: 2
        ) == 5)
    }

    @Test
    func keepsBaseRowUntilCapacityIsExceeded() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 5,
            currentVisible: 5,
            baseSlotCount: 5,
            maxAdditionalRows: 2
        ) == 5)
    }

    @Test
    func growsByFullAdditionalRows() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 6,
            currentVisible: 5,
            baseSlotCount: 5,
            maxAdditionalRows: 2
        ) == 10)
    }

    @Test
    func cappedAtMaximumAdditionalRows() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 20,
            currentVisible: 15,
            baseSlotCount: 5,
            maxAdditionalRows: 2
        ) == 15)
    }

    @Test
    func additionalRowsCanBeDisabled() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 6,
            currentVisible: 5,
            baseSlotCount: 5,
            maxAdditionalRows: 0
        ) == 5)
    }

    @Test
    func shrinksBackToBaseRowWhenItemsAreRemoved() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 3,
            currentVisible: 10,
            baseSlotCount: 5,
            maxAdditionalRows: 2
        ) == 5)
    }

    @Test
    func respectsLargerBaseRow() {
        #expect(SlotCountPolicy.visibleSlotCount(
            filledItems: 11,
            currentVisible: 10,
            baseSlotCount: 10,
            maxAdditionalRows: 3
        ) == 20)
    }
}

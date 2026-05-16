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
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 4, currentVisible: 5, min: 4, max: 16) == 6)
    }

    @Test
    func doesNotGrowWhileMoreThanTwoFreeRemain() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 1, currentVisible: 4, min: 4, max: 16) == 4)
    }

    @Test
    func cappedAtMaximum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 15, currentVisible: 16, min: 4, max: 16) == 16)
    }

    @Test
    func shrinksWhenAtLeastOneFullRowIsFreeBeyondMinimum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 3, currentVisible: 10, min: 4, max: 16) == 5)
    }

    @Test
    func normalizesUnalignedVisibleSlotsBeforeShrinking() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 0, currentVisible: 5, min: 4, max: 15) == 4)
    }

    @Test
    func neverShrinksBelowMinimum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 0, currentVisible: 5, min: 5, max: 15) == 5)
    }
}

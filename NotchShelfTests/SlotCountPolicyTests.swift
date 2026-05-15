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
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 3, currentVisible: 5, min: 5, max: 15) == 10)
    }

    @Test
    func doesNotGrowWhileMoreThanTwoFreeRemain() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 2, currentVisible: 5, min: 5, max: 15) == 5)
    }

    @Test
    func cappedAtMaximum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 13, currentVisible: 15, min: 5, max: 15) == 15)
    }

    @Test
    func shrinksWhenAtLeastOneFullRowIsFreeBeyondMinimum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 2, currentVisible: 10, min: 5, max: 15) == 5)
    }

    @Test
    func neverShrinksBelowMinimum() {
        #expect(SlotCountPolicy.visibleSlotCount(filledItems: 0, currentVisible: 5, min: 5, max: 15) == 5)
    }
}

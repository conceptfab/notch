import Testing
import Foundation
@testable import NotchShelf

@MainActor
private func items(_ n: Int) -> [ShelfItem] {
    (0..<n).map { _ in ShelfItem(bookmarkData: Data([UInt8.random(in: 0...255)])) }
}

@MainActor @Test func selectSingleReplacesSelection() {
    let sel = ShelfSelection()
    let all = items(3)
    sel.selectSingle(all[0])
    sel.selectSingle(all[2])
    #expect(sel.selectedIDs == [all[2].id])
}

@MainActor @Test func toggleAddsAndRemoves() {
    let sel = ShelfSelection()
    let all = items(3)
    sel.toggle(all[0])
    sel.toggle(all[1])
    #expect(sel.selectedIDs == [all[0].id, all[1].id])
    sel.toggle(all[0])
    #expect(sel.selectedIDs == [all[1].id])
}

@MainActor @Test func shiftSelectSelectsInclusiveRange() {
    let sel = ShelfSelection()
    let all = items(5)
    sel.selectSingle(all[1])
    sel.shiftSelect(to: all[3], in: all)
    #expect(sel.selectedIDs == Set(all[1...3].map(\.id)))
}

@MainActor @Test func clearEmptiesSelection() {
    let sel = ShelfSelection()
    let all = items(2)
    sel.selectSingle(all[0])
    sel.clear()
    #expect(sel.selectedIDs.isEmpty)
}

@MainActor @Test func dragStateTracks() {
    let sel = ShelfSelection()
    #expect(sel.isDragging == false)
    sel.beginDrag()
    #expect(sel.isDragging == true)
    sel.endDrag()
    #expect(sel.isDragging == false)
}

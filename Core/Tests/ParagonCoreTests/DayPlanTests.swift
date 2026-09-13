import XCTest
@testable import ParagonCore

final class DayPlanTests: XCTestCase {
    private func daily(_ body: String) -> Note {
        Note(relativePath: "Calendar/20260913.md", kind: .daily,
             text: "---\ntitle: Sunday, 13 September 2026\ntype: daily\n---\n" + body)
    }

    func testReadsTheBlocksUnderThePlanHeading() {
        let note = daily("""
        # Sunday

        ## Plan

        - 13:00-14:00 Pack for Granden
        - 9:30 – 11:00 Deep work on the IM plan
        * 15:00—15:45 Admin

        ## Tasks

        - [ ] 08:00-09:00 This is a task, not a block

        """)
        let blocks = note.planBlocks
        XCTAssertEqual(blocks.map(\.title), ["Deep work on the IM plan", "Pack for Granden", "Admin"])
        XCTAssertEqual(blocks.map(\.startText), ["09:30", "13:00", "15:00"])
        XCTAssertEqual(blocks.map(\.index), [0, 1, 2])
        XCTAssertEqual(blocks.first?.minutes, 90)
        XCTAssertEqual(blocks.first?.timeText, "09:30 \u{2013} 11:00")
    }

    func testANoteWithNoPlanHasNoBlocks() {
        XCTAssertTrue(daily("# Sunday\n\n## Tasks\n\n- [ ] Something\n").planBlocks.isEmpty)
    }

    func testWritingReplacesOnlyThePlanSection() {
        let note = daily("""
        # Sunday

        ## Plan

        - 09:30-11:00 Old

        ## Tasks

        - [ ] Keep me

        ## Notes

        Keep this too.

        """)
        let updated = note.settingPlanBlocks([PlanBlock(start: 13 * 60, end: 14 * 60, title: "Pack for Granden")])
        XCTAssertEqual(updated.planBlocks.map(\.title), ["Pack for Granden"])
        XCTAssertFalse(updated.body.contains("Old"))
        XCTAssertTrue(updated.body.contains("- [ ] Keep me"))
        XCTAssertTrue(updated.body.contains("Keep this too."))
        XCTAssertTrue(updated.body.contains("- 13:00-14:00 Pack for Granden"))
    }

    func testThePlanSectionIsMadeAboveTasksWhenItIsMissing() {
        let note = daily("# Sunday\n\n## Tasks\n\n- [ ] Something\n\n## Notes\n\n")
        let updated = note.addingPlanBlock(PlanBlock(start: 9 * 60, end: 10 * 60, title: "Write"))
        let lines = updated.body.components(separatedBy: "\n")
        let plan = lines.firstIndex(of: "## Plan")
        let tasks = lines.firstIndex(of: "## Tasks")
        XCTAssertNotNil(plan)
        XCTAssertNotNil(tasks)
        XCTAssertLessThan(plan ?? 99, tasks ?? 0)
        XCTAssertEqual(updated.planBlocks.map(\.title), ["Write"])
        XCTAssertTrue(updated.body.contains("- [ ] Something"))
    }

    func testEmptyingThePlanKeepsTheHeading() {
        let note = daily("# Sunday\n\n## Plan\n\n- 09:30-11:00 Old\n\n## Tasks\n\n")
        let updated = note.settingPlanBlocks([])
        XCTAssertTrue(updated.body.contains("## Plan"))
        XCTAssertTrue(updated.planBlocks.isEmpty)
        XCTAssertTrue(updated.body.contains("## Tasks"))
    }

    func testRemovingOneBlockLeavesTheOthers() {
        let note = daily("# Sunday\n\n## Plan\n\n- 09:00-10:00 One\n- 11:00-12:00 Two\n- 13:00-14:00 Three\n")
        let updated = note.removingPlanBlock(at: 1)
        XCTAssertEqual(updated.planBlocks.map(\.title), ["One", "Three"])
    }

    func testWhatIsWrittenIsReadBackTheSame() {
        let blocks = [
            PlanBlock(start: 9 * 60 + 5, end: 10 * 60 + 35, title: "Ride"),
            PlanBlock(start: 60, end: 90, title: "Small hours"),
        ]
        let note = daily("# Sunday\n\n## Tasks\n\n").settingPlanBlocks(blocks)
        XCTAssertEqual(note.planBlocks.map(\.startText), ["01:00", "09:05"])
        XCTAssertEqual(note.planBlocks.map(\.endText), ["01:30", "10:35"])
        XCTAssertEqual(note.planBlocks.map(\.title), ["Small hours", "Ride"])
    }

    func testNonsenseTimesAreRefusedRatherThanGuessed() {
        XCTAssertNil(PlanBlock.minutes(from: "25:00"))
        XCTAssertNil(PlanBlock.minutes(from: "09:70"))
        XCTAssertNil(PlanBlock.minutes(from: "morning"))
        XCTAssertEqual(PlanBlock.minutes(from: " 9:05 "), 545)
        XCTAssertEqual(PlanBlock.clock(545), "09:05")
    }

    func testABlockThatEndsBeforeItStartsIsNotNegative() {
        let block = PlanBlock(start: 600, end: 300, title: "Wrong way round")
        XCTAssertEqual(block.minutes, 1)
    }

    // MARK: The tie to Apple Calendar

    func testTheKeyNamesTheDayTheStartAndTheTitle() {
        let day = DateOnly(year: 2026, month: 9, day: 13)
        let block = PlanBlock(start: 9 * 60 + 30, end: 11 * 60, title: "Deep work on the IM plan")
        XCTAssertEqual(PlanBlockLink.key(for: block, on: day),
                       "ams-para:planblock 2026-09-13 09:30 Deep work on the IM plan")
    }

    func testTheKeyIsFoundAmongTheOtherLinesOfAnEventsNotes() {
        let day = DateOnly(year: 2026, month: 9, day: 13)
        let block = PlanBlock(start: 9 * 60 + 30, end: 11 * 60, title: "Deep work on the IM plan")
        // What the event really carries: our sentence, our key, and the older time-block marker
        // the calendar store appends to everything it writes.
        let notes = PlanBlockLink.notes(for: block, on: day) + "\n\nams-para:timeblock"
        XCTAssertTrue(PlanBlockLink.belongs(notes, to: block, on: day))
        XCTAssertEqual(PlanBlockLink.key(inNotes: notes), PlanBlockLink.key(for: block, on: day))
    }

    func testAnEventWithNoKeyBelongsToNoBlock() {
        let day = DateOnly(year: 2026, month: 9, day: 13)
        let block = PlanBlock(start: 540, end: 600, title: "Ride")
        XCTAssertNil(PlanBlockLink.key(inNotes: "Just an ordinary event.\nams-para:timeblock"))
        XCTAssertFalse(PlanBlockLink.belongs("Just an ordinary event.", to: block, on: day))
    }

    func testMovingOrRenamingABlockChangesItsKey() {
        let day = DateOnly(year: 2026, month: 9, day: 13)
        let block = PlanBlock(start: 540, end: 600, title: "Ride")
        let notes = PlanBlockLink.notes(for: block, on: day)
        var moved = block
        moved.start = 600
        moved.end = 660
        XCTAssertFalse(PlanBlockLink.belongs(notes, to: moved, on: day))
        var renamed = block
        renamed.title = "Ride to Granden"
        XCTAssertFalse(PlanBlockLink.belongs(notes, to: renamed, on: day))
        // And the same block on another day is a different block.
        XCTAssertFalse(PlanBlockLink.belongs(notes, to: block, on: day.adding(days: 1)))
    }

    func testTheKeyIgnoresTheEndTimeSoAResizeKeepsTheTie() {
        let day = DateOnly(year: 2026, month: 9, day: 13)
        let block = PlanBlock(start: 540, end: 600, title: "Ride")
        var longer = block
        longer.end = 720
        XCTAssertTrue(PlanBlockLink.belongs(PlanBlockLink.notes(for: block, on: day), to: longer, on: day))
    }
}

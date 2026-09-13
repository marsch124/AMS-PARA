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
}

import XCTest
@testable import AMSParaCore

final class NoteTests: XCTestCase {
    func testTitleFallsBackToFileName() {
        let note = Note(relativePath: "Projects/Garden shed.md", kind: .project, text: "# Shed\n")
        XCTAssertEqual(note.title, "Garden shed")
        XCTAssertEqual(note.remindersListName, "Garden shed")
    }

    func testAppendIntoExistingTasksSection() {
        var note = Note(relativePath: "Projects/P.md", kind: .project, text: """
        ---
        title: P
        ---
        # P

        ## Tasks

        - [ ] First


        ## Notes

        Text
        """)
        let appended = note.append(task: TaskItem(title: "Second", id: "t000001"))
        XCTAssertEqual(note.body, """
        # P

        ## Tasks

        - [ ] First
        - [ ] Second ^t000001


        ## Notes

        Text
        """)
        XCTAssertEqual(appended.lineIndex, 5)
        XCTAssertEqual(note.tasks.map(\.title), ["First", "Second"])
    }

    func testAppendCreatesTasksSectionWhenMissing() {
        var note = Note(relativePath: "Inbox.md", kind: .inbox, text: "# Inbox\n\nSome text\n\n\n")
        note.append(task: TaskItem(title: "New"))
        XCTAssertEqual(note.body, "# Inbox\n\nSome text\n\n## Tasks\n- [ ] New\n")
    }

    func testReplaceRewritesOnlyThatLine() {
        var note = Note(relativePath: "Inbox.md", kind: .inbox, text: "- [ ] A\n- [ ] B\n")
        var b = note.tasks[1]
        b.markDone(at: DoneStamp.date(from: "2026-09-05 08:00")!)
        XCTAssertTrue(note.replace(task: b))
        XCTAssertEqual(note.body, "- [ ] A\n- [x] B @done(2026-09-05 08:00)\n")
        XCTAssertEqual(note.text, note.body)
    }

    func testWikilinksAndOutgoingReferences() {
        let note = Note(relativePath: "Projects/P.md", kind: .project, text: """
        ---
        title: P
        area: Health
        related: [Resources/Diet]
        ---
        See [[Doctor visits]] and [[Doctor visits|again]] plus [[Gym#Plan]].
        """)
        XCTAssertEqual(note.wikilinks, ["Doctor visits", "Gym"])
        XCTAssertEqual(note.outgoingReferences, ["Resources/Diet", "Health", "Doctor visits", "Gym"])
    }

    func testSyncFlagAndArchiveStatus() {
        let off = Note(relativePath: "Projects/P.md", kind: .project, text: "---\nsync: false\n---\n")
        XCTAssertFalse(off.isSyncEnabled)
        let archived = Note(relativePath: "Projects/P.md", kind: .project, text: "---\nstatus: Archived\n---\n")
        XCTAssertTrue(archived.isArchived)
    }
}

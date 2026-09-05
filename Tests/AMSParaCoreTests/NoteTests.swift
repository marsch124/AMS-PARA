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

final class SubtaskNoteTests: XCTestCase {
    let text = """
    ## Tasks

    - [ ] Parent
        - [ ] Child A
        - [ ] Child B
    - [ ] Sibling
    """

    func testParentChainAndSyncTitle() {
        let note = Note(relativePath: "Inbox.md", kind: .inbox, text: text)
        let tasks = note.tasks
        XCTAssertEqual(note.parentChain(of: tasks[1]).map(\.title), ["Parent"])
        XCTAssertEqual(note.parentPrefix(for: tasks[1]), "Parent")
        XCTAssertEqual(note.syncTitle(for: tasks[1]), "Parent › Child A")
        XCTAssertNil(note.parentPrefix(for: tasks[0]))
        XCTAssertEqual(note.syncTitle(for: tasks[0]), "Parent")
        XCTAssertEqual(note.subtasks(of: tasks[0]).map(\.title), ["Child A", "Child B"])
    }

    func testAppendSubtaskGoesAfterLastDescendant() {
        var note = Note(relativePath: "Inbox.md", kind: .inbox, text: text)
        let parent = note.tasks[0]
        let child = note.appendSubtask(TaskItem(title: "Child C"), to: parent)
        XCTAssertEqual(child.lineIndex, 5)
        XCTAssertEqual(child.indent, "    ")
        XCTAssertEqual(note.lines[5], "    - [ ] Child C")
        XCTAssertEqual(note.tasks.map(\.title), ["Parent", "Child A", "Child B", "Child C", "Sibling"])
        XCTAssertEqual(note.tasks[3].parentLineIndex, 2)

        let sibling = note.tasks[4]
        note.appendSubtask(TaskItem(title: "Sibling's child"), to: sibling)
        XCTAssertEqual(note.lines.last, "    - [ ] Sibling's child")
    }
}

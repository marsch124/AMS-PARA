import XCTest
@testable import AMSParaCore

final class TaskParserTests: XCTestCase {
    func testParsesFullNotePlanStyleLine() throws {
        let line = "  - [ ] Call the bank #finance !! >2026-09-10 ^t3fa2c1"
        let task = try XCTUnwrap(TaskParser.parse(line: line, lineIndex: 4))
        XCTAssertEqual(task.status, .open)
        XCTAssertEqual(task.title, "Call the bank #finance")
        XCTAssertEqual(task.tags, ["finance"])
        XCTAssertEqual(task.priority, 2)
        XCTAssertEqual(task.dueDate, DateOnly(year: 2026, month: 9, day: 10))
        XCTAssertEqual(task.id, "t3fa2c1")
        XCTAssertEqual(task.indent, "  ")
        XCTAssertEqual(task.bullet, "-")
        XCTAssertEqual(task.lineIndex, 4)
        XCTAssertEqual(task.serialized, line)
    }

    func testParsesDoneCancelledAndScheduled() throws {
        let done = try XCTUnwrap(TaskParser.parse(line: "* [x] Pay invoice @done(2026-09-05 10:00)"))
        XCTAssertEqual(done.status, .done)
        XCTAssertEqual(done.doneStamp, "2026-09-05 10:00")
        XCTAssertTrue(done.isDone)
        XCTAssertNotNil(done.doneDate)
        XCTAssertEqual(done.serialized, "* [x] Pay invoice @done(2026-09-05 10:00)")

        let cancelled = try XCTUnwrap(TaskParser.parse(line: "- [-] Old idea"))
        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertTrue(cancelled.isDone)

        let scheduled = try XCTUnwrap(TaskParser.parse(line: "- [>] Moved >2026-10-01"))
        XCTAssertEqual(scheduled.status, .scheduled)
        XCTAssertFalse(scheduled.isDone)
    }

    func testNonTaskLinesReturnNil() {
        XCTAssertNil(TaskParser.parse(line: "- plain bullet"))
        XCTAssertNil(TaskParser.parse(line: "# Heading"))
        XCTAssertNil(TaskParser.parse(line: "- [ ]glued"))
        XCTAssertNil(TaskParser.parse(line: ""))
    }

    func testExclamationInsideWordsIsNotPriority() throws {
        let task = try XCTUnwrap(TaskParser.parse(line: "- [ ] Wow! really !!!"))
        XCTAssertEqual(task.title, "Wow! really")
        XCTAssertEqual(task.priority, 3)
    }

    func testIgnoresTasksInsideCodeFences() {
        let text = """
        - [ ] Real task
        ```
        - [ ] Not a task
        ```
        - [x] Another real one
        """
        let tasks = TaskParser.parse(text: text)
        XCTAssertEqual(tasks.map(\.title), ["Real task", "Another real one"])
        XCTAssertEqual(tasks.map(\.lineIndex), [0, 4])
    }

    func testMarkDoneAndOpenRoundTrip() throws {
        var task = try XCTUnwrap(TaskParser.parse(line: "- [ ] Write report"))
        task.markDone(at: DoneStamp.date(from: "2026-09-05 09:30")!)
        XCTAssertEqual(task.serialized, "- [x] Write report @done(2026-09-05 09:30)")
        task.markOpen()
        XCTAssertEqual(task.serialized, "- [ ] Write report")
    }

    func testMakeIDFormat() {
        let id = TaskItem.makeID()
        XCTAssertEqual(id.count, 7)
        XCTAssertTrue(id.hasPrefix("t"))
        XCTAssertNotNil(TaskParser.parse(line: "- [ ] x ^\(id)")?.id)
    }
}

final class TaskTimeAndSubtaskParserTests: XCTestCase {
    func testParsesDueTime() throws {
        let task = try XCTUnwrap(TaskParser.parse(line: "- [ ] Dentist >2026-09-15T14:30 !"))
        XCTAssertEqual(task.dueDate, DateOnly(year: 2026, month: 9, day: 15))
        XCTAssertEqual(task.dueTime, TimeOfDay(hour: 14, minute: 30))
        XCTAssertEqual(task.title, "Dentist")
        XCTAssertEqual(task.serialized, "- [ ] Dentist ! >2026-09-15T14:30")
        XCTAssertNotNil(task.dueMoment())

        let dateOnly = try XCTUnwrap(TaskParser.parse(line: "- [ ] Dentist >2026-09-15"))
        XCTAssertNil(dateOnly.dueTime)
        XCTAssertEqual(dateOnly.serialized, "- [ ] Dentist >2026-09-15")
    }

    func testTimeOfDayParsing() {
        XCTAssertEqual(TimeOfDay("9:05"), TimeOfDay(hour: 9, minute: 5))
        XCTAssertEqual(TimeOfDay("23:59")?.description, "23:59")
        XCTAssertNil(TimeOfDay("24:00"))
        XCTAssertNil(TimeOfDay("nope"))
        XCTAssertTrue(TimeOfDay(hour: 8, minute: 0) < TimeOfDay(hour: 8, minute: 1))
    }

    func testSubtasksGetParentLineIndex() {
        let text = """
        - [ ] Parent
            - [ ] Child A
            - [x] Child B
                - [ ] Grandchild
        - [ ] Sibling
        ## Heading
            - [ ] Indented but after a heading
        """
        let tasks = TaskParser.parse(text: text)
        XCTAssertEqual(tasks.map(\.title), ["Parent", "Child A", "Child B", "Grandchild", "Sibling", "Indented but after a heading"])
        XCTAssertEqual(tasks.map(\.parentLineIndex), [nil, 0, 0, 2, nil, nil])
        XCTAssertEqual(tasks.map(\.indentLevel), [0, 2, 2, 4, 0, 2])
        XCTAssertTrue(tasks[1].isSubtask)
        XCTAssertFalse(tasks[4].isSubtask)
    }
}

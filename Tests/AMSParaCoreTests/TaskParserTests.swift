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

import XCTest
@testable import AMSParaCore

final class WeekRefTests: XCTestCase {
    func testIsoWeekOfASaturday() {
        let week = WeekRef(containing: DateOnly(year: 2026, month: 9, day: 5))
        XCTAssertEqual(week, WeekRef(year: 2026, week: 36))
        XCTAssertEqual(week.description, "2026-W36")
        XCTAssertEqual(week.monday, DateOnly(year: 2026, month: 8, day: 31))
        XCTAssertEqual(week.sunday, DateOnly(year: 2026, month: 9, day: 6))
        XCTAssertEqual(week.days.count, 7)
        XCTAssertTrue(week.contains(DateOnly(year: 2026, month: 9, day: 6)))
        XCTAssertFalse(week.contains(DateOnly(year: 2026, month: 9, day: 7)))
    }

    func testYearBoundaryBelongsToPreviousIsoYear() {
        let week = WeekRef(containing: DateOnly(year: 2027, month: 1, day: 1))
        XCTAssertEqual(week, WeekRef(year: 2026, week: 53))
        XCTAssertEqual(week.monday, DateOnly(year: 2026, month: 12, day: 28))
        XCTAssertEqual(week.adding(weeks: 1), WeekRef(year: 2027, week: 1))
        XCTAssertEqual(WeekRef(year: 2027, week: 1).monday, DateOnly(year: 2027, month: 1, day: 4))
    }

    func testParsing() {
        XCTAssertEqual(WeekRef("2026-W36"), WeekRef(year: 2026, week: 36))
        XCTAssertEqual(WeekRef("2026-w05"), WeekRef(year: 2026, week: 5))
        XCTAssertNil(WeekRef("2026-W54"))
        XCTAssertNil(WeekRef("20260905"))
        XCTAssertNil(WeekRef("Website relaunch"))
    }

    func testMonthRef() {
        let sep = MonthRef(year: 2026, month: 9)
        XCTAssertEqual(sep.dayCount, 30)
        XCTAssertEqual(sep.adding(months: 1), MonthRef(year: 2026, month: 10))
        XCTAssertEqual(sep.adding(months: 4), MonthRef(year: 2027, month: 1))
        XCTAssertEqual(sep.adding(months: -9), MonthRef(year: 2025, month: 12))
        XCTAssertEqual(MonthRef(year: 2028, month: 2).dayCount, 29)
        XCTAssertEqual(MonthRef(containing: DateOnly(year: 2026, month: 9, day: 5)), sep)
    }
}

final class WeeklyNoteAndOverviewTests: XCTestCase {
    var vault: Vault!
    let week = WeekRef(year: 2026, week: 36)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testWeeklyNoteIsCreatedFromTemplate() throws {
        XCTAssertFalse(vault.weeklyNoteExists(for: week))
        let note = try vault.weeklyNote(for: week)
        XCTAssertEqual(note.relativePath, "Calendar/2026-W36.md")
        XCTAssertEqual(note.weekRef, week)
        XCTAssertTrue(note.isWeeklyNote)
        XCTAssertNil(note.dailyDate)
        XCTAssertTrue(note.body.hasPrefix("# Week 36, "))
        XCTAssertTrue(note.body.contains("## Focus"))
        XCTAssertTrue(vault.weeklyNoteExists(for: week))
        XCTAssertEqual(note.displayTitle, week.title)
    }

    func testCalendarNotesSortNewestFirstWithWeeklyBeforeItsMonday() throws {
        _ = try vault.dailyNote(for: DateOnly(year: 2026, month: 8, day: 31))
        _ = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 5))
        _ = try vault.weeklyNote(for: week)
        let names = try vault.notes(kind: .daily).map(\.fileName)
        XCTAssertEqual(names, ["20260905", "2026-W36", "20260831"])
        let index = NoteIndex(notes: try vault.allNotes())
        XCTAssertEqual(index.dailyNotes.map(\.fileName), names)
        XCTAssertEqual(index.weeklyNote(for: week)?.relativePath, "Calendar/2026-W36.md")
    }

    func testWeekAndMonthOverviews() throws {
        var project = try vault.createNote(kind: .project, title: "Shed")
        project.body = "- [ ] Order timber >2026-09-02\n- [ ] Pick up timber >2026-09-05T10:00\n- [x] Measure @done(2026-09-01 09:00)\n- [ ] Next month >2026-10-03\n"
        try vault.save(project)
        var daily = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 5))
        daily.body += "- [ ] Water the plants\n- [x] Run @done(2026-09-05 08:00)\n"
        try vault.save(daily)
        _ = try vault.weeklyNote(for: week)

        let index = NoteIndex(notes: try vault.allNotes())
        let overview = index.weekOverview(for: week)
        XCTAssertEqual(overview.weeklyNotePath, "Calendar/2026-W36.md")
        XCTAssertEqual(overview.days.map(\.date.day), [31, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(overview.dueCount, 2)
        XCTAssertEqual(overview.completedCount, 2)
        let saturday = overview.days[5]
        XCTAssertEqual(saturday.dailyNotePath, "Calendar/20260905.md")
        XCTAssertEqual(saturday.due.map(\.task.title), ["Pick up timber"])
        XCTAssertEqual(saturday.completed.map(\.task.title), ["Run"])
        XCTAssertEqual(saturday.undated.map(\.task.title), ["Water the plants"])
        XCTAssertEqual(overview.days[1].completed.map(\.task.title), ["Measure"])
        XCTAssertTrue(overview.days[3].isEmpty)

        let month = index.monthOverview(for: MonthRef(year: 2026, month: 9))
        XCTAssertEqual(month.days.count, 30)
        XCTAssertEqual(month.dueCount, 2)
        XCTAssertEqual(index.monthOverview(for: MonthRef(year: 2026, month: 10)).dueCount, 1)
    }
}

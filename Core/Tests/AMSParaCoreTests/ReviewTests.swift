import XCTest
@testable import AMSParaCore

final class ReviewTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 9, day: 5)
    let config = VaultConfig()

    private func project(_ title: String, body: String, status: String? = nil, due: String? = nil,
                         reviewed: String? = nil, modifiedDaysAgo: Int = 0) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "project")
        if let status { fm.set("status", status) }
        if let due { fm.set("due", due) }
        if let reviewed { fm.set("reviewed", reviewed) }
        let modified = today.adding(days: -modifiedDaysAgo).date()
        return Note(relativePath: "Projects/\(title).md", kind: .project, frontmatter: fm, body: body, modifiedAt: modified)
    }

    func testFlagsForProjects() {
        let healthy = project("Healthy", body: "- [ ] Next step >2026-09-10\n- [x] Done @done(2026-09-03 10:00)\n", reviewed: "2026-09-01")
        let empty = project("Empty", body: "- [x] Finished @done(2026-08-01 10:00)\n", reviewed: "2026-09-04")
        let late = project("Late", body: "- [ ] Overdue >2026-09-01\n", due: "2026-09-02", reviewed: "2026-08-20", modifiedDaysAgo: 20)
        let paused = project("Paused", body: "", status: "on-hold")
        let index = NoteIndex(notes: [healthy, empty, late, paused])

        let h = index.health(of: healthy, today: today, config: config)
        XCTAssertEqual(h.flags, [])
        XCTAssertEqual(h.openTaskCount, 1)
        XCTAssertEqual(h.completedLast7Days, 1)
        XCTAssertEqual(h.daysSinceReview, 4)
        XCTAssertFalse(h.needsAttention)

        XCTAssertEqual(index.health(of: empty, today: today, config: config).flags, [.noNextAction])

        let l = index.health(of: late, today: today, config: config)
        XCTAssertEqual(l.flags, [.overdueTasks, .pastDue, .stale, .reviewDue])
        XCTAssertEqual(l.overdueTaskCount, 1)
        XCTAssertEqual(l.daysSinceModified, 20)

        let p = index.health(of: paused, today: today, config: config)
        XCTAssertEqual(p.flags, [.onHold])
        XCTAssertFalse(p.needsAttention)
    }

    func testNeverReviewedProjectIsFlagged() {
        let note = project("New", body: "- [ ] Start\n")
        let health = NoteIndex(notes: [note]).health(of: note, today: today, config: config)
        XCTAssertEqual(health.flags, [.reviewDue])
        XCTAssertNil(health.daysSinceReview)
    }

    func testReviewReportOrdersAttentionFirstAndCountsCompleted() {
        let inbox = Note(relativePath: "Inbox.md", kind: .inbox, text: "- [ ] One\n- [ ] Two\n- [x] Three @done(2026-09-04 09:00)\n")
        let fine = project("A fine one", body: "- [ ] Next\n", reviewed: "2026-09-04")
        let bad = project("Zzz needs work", body: "- [ ] Late >2026-08-30\n", reviewed: "2026-09-04")
        let archived = project("Archived", body: "", status: "archived")
        let report = NoteIndex(notes: [inbox, fine, bad, archived]).review(today: today, config: config)

        XCTAssertEqual(report.inboxOpenTasks, 2)
        XCTAssertEqual(report.projects.map(\.note.title), ["Zzz needs work", "A fine one"])
        XCTAssertEqual(report.projectsNeedingAttention.map(\.note.title), ["Zzz needs work"])
        XCTAssertEqual(report.completedLast7Days, 1)
        XCTAssertEqual(report.overdueTasks.map(\.task.title), ["Late"])
    }

    func testDateArithmetic() {
        XCTAssertEqual(today.adding(days: -7), DateOnly(year: 2026, month: 8, day: 29))
        XCTAssertEqual(today.days(since: DateOnly(year: 2026, month: 8, day: 29)), 7)
        XCTAssertEqual(DateOnly(year: 2026, month: 8, day: 29).days(since: today), -7)
    }
}

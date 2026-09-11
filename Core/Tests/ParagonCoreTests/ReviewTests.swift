import XCTest
@testable import ParagonCore

final class ReviewTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 9, day: 5)
    let config = VaultConfig()

    private func project(_ title: String, body: String, status: String? = nil, due: String? = nil,
                         reviewed: String? = nil, modifiedDaysAgo: Int = 0,
                         goal: String? = "Some goal") -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "project")
        if let goal { fm.set("goal", goal) }
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

    // MARK: The chain — a project must serve a goal, and finish before it

    private func goalNote(_ title: String, horizon: String = "year", target: String? = nil,
                          serves: String? = nil) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "goal")
        fm.set("horizon", horizon)
        if let target { fm.set("target", target) }
        if let serves { fm.set("goal", serves) }
        return Note(relativePath: "Goals/\(title).md", kind: .goal, frontmatter: fm, body: "",
                    modifiedAt: today.date())
    }

    private func areaNote(_ title: String, serves: String? = nil) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", "area")
        if let serves { fm.set("goal", serves) }
        return Note(relativePath: "Areas/\(title).md", kind: .area, frontmatter: fm, body: "",
                    modifiedAt: today.date())
    }

    func testProjectWithoutAGoalIsFlaggedButIsNotAnAlarm() {
        let orphan = project("Hobby", body: "- [ ] Potter about\n", reviewed: "2026-09-04", goal: nil)
        let health = NoteIndex(notes: [orphan]).health(of: orphan, today: today, config: config)
        XCTAssertEqual(health.flags, [.noGoal])
        // The question belongs in the review, not in the red column: a vault written before
        // the chain would otherwise show every project as needing attention.
        XCTAssertFalse(health.needsAttention)
    }

    func testAnAreaWithoutAGoalIsNotFlagged() {
        let area = areaNote("Endurance")
        let health = NoteIndex(notes: [area]).health(of: area, today: today, config: config)
        XCTAssertFalse(health.flags.contains(.noGoal))
    }

    func testProjectDueAfterItsGoalIsFlagged() {
        let race = goalNote("Finish the race", target: "2027-07-11")
        let inTime = project("Training plan", body: "- [ ] Swim\n", due: "2027-06-01",
                             reviewed: "2026-09-04", goal: "Finish the race")
        let tooLate = project("Bike ready", body: "- [ ] Order wheels\n", due: "2027-08-01",
                              reviewed: "2026-09-04", goal: "Finish the race")
        let index = NoteIndex(notes: [race, inTime, tooLate])

        XCTAssertFalse(index.health(of: inTime, today: today, config: config).flags.contains(.dueAfterGoal))
        let late = index.health(of: tooLate, today: today, config: config)
        XCTAssertTrue(late.flags.contains(.dueAfterGoal))
        // This one *is* an alarm: it cannot be true and the goal still be reached.
        XCTAssertTrue(late.needsAttention)
    }

    func testProjectDueAfterAGoalThatHasNoTargetIsNotFlagged() {
        let open = goalNote("Someday", target: nil)
        let work = project("Work", body: "- [ ] Step\n", due: "2030-01-01",
                           reviewed: "2026-09-04", goal: "Someday")
        let health = NoteIndex(notes: [open, work]).health(of: work, today: today, config: config)
        XCTAssertFalse(health.flags.contains(.dueAfterGoal))
    }

    func testGoalServedOnlyByAnAreaHasNoPathYet() {
        let goal = goalNote("Living as nomads", horizon: "long", target: "2028-12-31")
        let area = areaNote("Living & Finance", serves: "Living as nomads")
        let health = NoteIndex(notes: [goal, area]).goalHealth(of: goal, today: today)
        XCTAssertTrue(health.flags.contains(.noProjectYet))
        XCTAssertFalse(health.flags.contains(.nothingServing))
    }

    func testGoalWithAProjectHasAPath() {
        let goal = goalNote("Living as nomads", horizon: "long", target: "2028-12-31")
        let area = areaNote("Living & Finance", serves: "Living as nomads")
        let work = project("Set the nomad budget", body: "- [ ] Pull 12 months\n",
                           reviewed: "2026-09-04", goal: "Living as nomads")
        let health = NoteIndex(notes: [goal, area, work]).goalHealth(of: goal, today: today)
        XCTAssertFalse(health.flags.contains(.noProjectYet))
    }

    func testLifeGoalReachedThroughDatedGoalsIsNotFlagged() {
        // An aspiration carries no projects of its own; its path is the dated goals below it.
        let life = goalNote("Still racing at seventy", horizon: "life")
        let dated = goalNote("Finish the race", target: "2027-07-11", serves: "Still racing at seventy")
        let work = project("Training plan", body: "- [ ] Swim\n", reviewed: "2026-09-04",
                           goal: "Finish the race")
        let health = NoteIndex(notes: [life, dated, work]).goalHealth(of: life, today: today)
        XCTAssertEqual(health.subgoals.map(\.title), ["Finish the race"])
        XCTAssertFalse(health.flags.contains(.noProjectYet))
        XCTAssertFalse(health.flags.contains(.nothingServing))
    }

    func testReportCountsProjectsWithoutAGoalSeparately() {
        let served = project("Served", body: "- [ ] Next\n", reviewed: "2026-09-04")
        let orphan = project("Orphan", body: "- [ ] Next\n", reviewed: "2026-09-04", goal: nil)
        let report = NoteIndex(notes: [served, orphan]).review(today: today, config: config)
        XCTAssertEqual(report.projectsWithoutGoal.map(\.note.title), ["Orphan"])
        XCTAssertTrue(report.projectsNeedingAttention.isEmpty)
    }

    func testDateArithmetic() {
        XCTAssertEqual(today.adding(days: -7), DateOnly(year: 2026, month: 8, day: 29))
        XCTAssertEqual(today.days(since: DateOnly(year: 2026, month: 8, day: 29)), 7)
        XCTAssertEqual(DateOnly(year: 2026, month: 8, day: 29).days(since: today), -7)
    }
}

import XCTest
@testable import ParagonCore

final class GoalTests: XCTestCase {
    var vault: Vault!
    let today = DateOnly(year: 2026, month: 9, day: 6)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testGoalNotesLiveInTheirOwnFolderAndNeverSync() throws {
        let goal = try vault.createNote(kind: .goal, title: "Stay fit for the mountains", extraFrontmatter: [("horizon", "life")])
        XCTAssertEqual(goal.relativePath, "Goals/Stay fit for the mountains.md")
        XCTAssertEqual(goal.kind, .goal)
        XCTAssertEqual(goal.horizon, .life)
        XCTAssertFalse(goal.kind.isTaskKind)
        XCTAssertTrue(goal.body.contains("## Why"))
        XCTAssertEqual(vault.kind(forRelativePath: "Goals/Stay fit for the mountains.md"), .goal)

        let engine = SyncEngine(vault: vault, store: InMemoryRemindersStore(), deviceID: "t")
        XCTAssertTrue(engine.syncableNotes(from: [goal]).isEmpty)
    }

    func testHorizonDefaultsToYearAndParsesTargets() {
        let dated = Note(relativePath: "Goals/Kungsleden.md", kind: .goal, text: "---\ntitle: Walk the Kungsleden\ntarget: 2028-08-15\nmeasure: Finish all 440 km\n---\n")
        XCTAssertEqual(dated.horizon, .year)
        XCTAssertEqual(dated.targetDate, DateOnly(year: 2028, month: 8, day: 15))
        XCTAssertEqual(dated.measure, "Finish all 440 km")
        XCTAssertFalse(dated.isAchieved)

        let project = Note(relativePath: "Projects/P.md", kind: .project, text: "---\ngoal: Walk the Kungsleden\n---\n")
        XCTAssertNil(project.horizon)
        XCTAssertEqual(project.goal, "Walk the Kungsleden")
        XCTAssertEqual(project.outgoingReferences, ["Walk the Kungsleden"])
    }

    func testGoalHealthRollsUpServingProjectsAndAreas() throws {
        let life = try vault.createNote(kind: .goal, title: "Stay fit for the mountains", extraFrontmatter: [("horizon", "life")])
        let dated = try vault.createNote(kind: .goal, title: "Walk the Kungsleden",
                                         extraFrontmatter: [("horizon", "year"), ("target", "2028-08-15"), ("goal", "Stay fit for the mountains")])
        var project = try vault.createNote(kind: .project, title: "Run a 10k", extraFrontmatter: [("goal", "Walk the Kungsleden")])
        project.body = "- [ ] Register\n- [x] Week 1 run @done(2026-09-01 08:00)\n- [x] Old @done(2026-06-01 08:00)\n"
        try vault.save(project)
        var area = try vault.createNote(kind: .area, title: "Health", extraFrontmatter: [("goal", "Stay fit for the mountains")])
        area.body = "- [ ] Yearly check-up\n"
        try vault.save(area)
        _ = try vault.createNote(kind: .goal, title: "Learn Italian", extraFrontmatter: [("horizon", "year"), ("target", "2026-01-01")])

        let index = NoteIndex(notes: try vault.allNotes())

        let datedHealth = index.goalHealth(of: dated, today: today)
        XCTAssertEqual(datedHealth.projects.map(\.title), ["Run a 10k"])
        XCTAssertTrue(datedHealth.areas.isEmpty)
        XCTAssertEqual(datedHealth.openTaskCount, 1)
        XCTAssertEqual(datedHealth.completedLast30Days, 1)
        XCTAssertLessThan(datedHealth.daysSinceActivity ?? 99, 30) // files were just written
        XCTAssertEqual(datedHealth.flags, [])
        XCTAssertFalse(datedHealth.needsAttention)

        let lifeHealth = index.goalHealth(of: life, today: today)
        XCTAssertEqual(lifeHealth.areas.map(\.title), ["Health"])
        XCTAssertEqual(lifeHealth.subgoals.map(\.title), ["Walk the Kungsleden"])
        XCTAssertEqual(lifeHealth.openTaskCount, 1)
        XCTAssertEqual(lifeHealth.flags, [])

        let orphan = index.goalHealth(of: index.note(matching: "Learn Italian")!, today: today)
        XCTAssertEqual(orphan.flags, [.nothingServing, .pastTarget])
        XCTAssertTrue(orphan.needsAttention)

        XCTAssertEqual(index.backlinks(to: dated).map(\.title), ["Run a 10k"])
        XCTAssertEqual(index.resources(for: dated), [])
    }

    func testReviewListsGoalsAttentionFirst() throws {
        _ = try vault.createNote(kind: .goal, title: "Served", extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .area, title: "Health", extraFrontmatter: [("goal", "Served")])
        _ = try vault.createNote(kind: .goal, title: "Abandoned", extraFrontmatter: [("horizon", "year")])
        _ = try vault.createNote(kind: .goal, title: "Done", extraFrontmatter: [("horizon", "year"), ("status", "achieved")])

        let report = NoteIndex(notes: try vault.allNotes()).review(today: today, config: vault.config)
        XCTAssertEqual(report.goals.map(\.note.title), ["Abandoned", "Served", "Done"])
        XCTAssertEqual(report.goalsNeedingAttention.map(\.note.title), ["Abandoned"])
        XCTAssertEqual(report.goals.last?.flags, [.achieved])
    }

    func testStaleGoalIsFlaggedAfterThirtyDays() throws {
        var goal = try vault.createNote(kind: .goal, title: "Quiet", extraFrontmatter: [("horizon", "year")])
        goal.modifiedAt = today.adding(days: -45).date()
        var project = Note(relativePath: "Projects/Old push.md", kind: .project,
                           text: "---\ntitle: Old push\ngoal: Quiet\n---\n- [x] Did it @done(2026-07-01 09:00)\n",
                           modifiedAt: today.adding(days: -60).date())
        project.frontmatter.set("status", "active")
        let health = NoteIndex(notes: [goal, project]).goalHealth(of: goal, today: today)
        XCTAssertEqual(health.daysSinceActivity, 45)
        XCTAssertEqual(health.flags, [.noRecentActivity])
    }

    func testProgressRollsUpFromProjectsToTheGoal() throws {
        let goal = try vault.createNote(kind: .goal, title: "Walk the Kungsleden",
                                        extraFrontmatter: [("horizon", "year"), ("target", "2028-08-15")])
        // Half of one project, none of another, and one finished.
        var half = try vault.createNote(kind: .project, title: "Train", extraFrontmatter: [("goal", "Walk the Kungsleden")])
        half.body = "- [x] Week 1 @done(2026-09-01 08:00)\n- [ ] Week 2\n"
        try vault.save(half)
        var untouched = try vault.createNote(kind: .project, title: "Book the train", extraFrontmatter: [("goal", "Walk the Kungsleden")])
        untouched.body = "- [ ] Buy the ticket\n"
        try vault.save(untouched)
        var done = try vault.createNote(kind: .project, title: "Buy the boots",
                                        extraFrontmatter: [("goal", "Walk the Kungsleden"), ("status", "done")])
        done.body = "- [x] Try them on @done(2026-08-01 08:00)\n- [ ] Never got round to this\n"
        try vault.save(done)
        // An area serves the same goal and must not be counted: it never finishes.
        var area = try vault.createNote(kind: .area, title: "Health", extraFrontmatter: [("goal", "Walk the Kungsleden")])
        area.body = "- [ ] Yearly check-up\n"
        try vault.save(area)

        let index = NoteIndex(notes: try vault.allNotes())
        let progress = index.progress(of: goal)
        XCTAssertEqual(progress.projectsDone, 1)
        XCTAssertEqual(progress.projectsTotal, 3)
        // Real counts, the finished project's open box included.
        XCTAssertEqual(progress.tasksDone, 2)
        XCTAssertEqual(progress.tasksTotal, 5)
        // One share each: 0.5 + 0 + 1, over three.
        XCTAssertEqual(progress.fraction ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.percent, 50)

        let health = index.goalHealth(of: goal, today: today)
        XCTAssertEqual(health.progress, progress)
        XCTAssertEqual(health.finishedProjects.map(\.title), ["Buy the boots"])
        XCTAssertEqual(health.projects.map(\.title).sorted(), ["Book the train", "Train"])
    }

    func testAnAspirationRollsUpThroughItsGoals() throws {
        let life = try vault.createNote(kind: .goal, title: "Stay fit", extraFrontmatter: [("horizon", "life")])
        _ = try vault.createNote(kind: .goal, title: "Kungsleden",
                                 extraFrontmatter: [("horizon", "year"), ("goal", "Stay fit")])
        _ = try vault.createNote(kind: .goal, title: "Vasaloppet",
                                 extraFrontmatter: [("horizon", "year"), ("goal", "Stay fit")])
        var walked = try vault.createNote(kind: .project, title: "Walk it",
                                          extraFrontmatter: [("goal", "Kungsleden"), ("status", "done")])
        walked.body = ""
        try vault.save(walked)
        var started = try vault.createNote(kind: .project, title: "Ski it", extraFrontmatter: [("goal", "Vasaloppet")])
        started.body = "- [x] Wax the skis @done(2026-09-01 08:00)\n- [ ] Enter\n- [ ] Get there\n- [ ] Finish\n"
        try vault.save(started)

        let index = NoteIndex(notes: try vault.allNotes())
        // The two goals count one share each: 1 and 0.25.
        let progress = index.progress(of: life)
        XCTAssertEqual(progress.fraction ?? 0, 0.625, accuracy: 0.0001)
        XCTAssertEqual(progress.projectsDone, 1)
        XCTAssertEqual(progress.projectsTotal, 2)
        XCTAssertEqual(progress.tasksDone, 1)
        XCTAssertEqual(progress.tasksTotal, 4)
    }

    func testNothingToMeasureIsNotZero() throws {
        let bare = try vault.createNote(kind: .goal, title: "Someday", extraFrontmatter: [("horizon", "year")])
        var index = NoteIndex(notes: try vault.allNotes())
        XCTAssertNil(index.progress(of: bare).fraction)
        XCTAssertNil(index.progress(of: bare).percent)

        // An area alone is still nothing to measure: an area never finishes.
        _ = try vault.createNote(kind: .area, title: "Admin", extraFrontmatter: [("goal", "Someday")])
        index = NoteIndex(notes: try vault.allNotes())
        XCTAssertNil(index.progress(of: bare).fraction)

        // A project with no tasks yet is zero, not nothing: it is a project that has not started.
        _ = try vault.createNote(kind: .project, title: "Start", extraFrontmatter: [("goal", "Someday")])
        index = NoteIndex(notes: try vault.allNotes())
        XCTAssertEqual(index.progress(of: bare).fraction, 0)
        XCTAssertEqual(index.progress(of: bare).percent, 0)
    }

    func testPerCentNeverRoundsToAFullOrEmptyGoal() {
        var almost = GoalProgress()
        almost.fraction = 0.999
        XCTAssertEqual(almost.percent, 99)
        var barely = GoalProgress()
        barely.fraction = 0.001
        XCTAssertEqual(barely.percent, 1)
        var full = GoalProgress()
        full.fraction = 1
        XCTAssertEqual(full.percent, 100)
    }

    func testAGoalWhoseProjectsAreAllDoneIsNotCalledUnserved() throws {
        let goal = try vault.createNote(kind: .goal, title: "Ship it",
                                        extraFrontmatter: [("horizon", "year"), ("target", "2030-01-01")])
        _ = try vault.createNote(kind: .project, title: "Build it",
                                 extraFrontmatter: [("goal", "Ship it"), ("status", "done")])

        let index = NoteIndex(notes: try vault.allNotes())
        let health = index.goalHealth(of: goal, today: today)
        XCTAssertTrue(health.projects.isEmpty)
        XCTAssertFalse(health.flags.contains(.nothingServing))
        XCTAssertFalse(health.flags.contains(.noProjectYet))
        XCTAssertEqual(health.progress.percent, 100)
    }

    func testTwoGoalsPointingAtEachOtherDoNotLoop() {
        let a = Note(relativePath: "Goals/A.md", kind: .goal, text: "---\ntitle: A\ntype: goal\nhorizon: year\ngoal: B\n---\n")
        let b = Note(relativePath: "Goals/B.md", kind: .goal, text: "---\ntitle: B\ntype: goal\nhorizon: year\ngoal: A\n---\n")
        let index = NoteIndex(notes: [a, b])
        XCTAssertNil(index.progress(of: a).fraction)
    }

    func testAnArchivedProjectStillCountsForItsGoal() {
        let goal = Note(relativePath: "Goals/G.md", kind: .goal, text: "---\ntitle: G\ntype: goal\nhorizon: year\n---\n")
        // Archiving moves the file, so its kind becomes .archive; `type:` is what remembers.
        let archived = Note(relativePath: "Archive/Old push.md", kind: .archive,
                            text: "---\ntitle: Old push\ntype: project\nstatus: done\ngoal: G\n---\n- [x] It @done(2026-01-01 09:00)\n")
        let index = NoteIndex(notes: [goal, archived])
        let progress = index.progress(of: goal)
        XCTAssertEqual(progress.projectsDone, 1)
        XCTAssertEqual(progress.projectsTotal, 1)
        XCTAssertEqual(progress.percent, 100)
    }

    func testAnArchivedProjectThatWasNeverFinishedIsLeftOut() {
        let goal = Note(relativePath: "Goals/G.md", kind: .goal, text: "---\ntitle: G\ntype: goal\nhorizon: year\n---\n")
        let live = Note(relativePath: "Projects/Live.md", kind: .project,
                        text: "---\ntitle: Live\ntype: project\nstatus: active\ngoal: G\n---\n- [x] One @done(2026-09-01 09:00)\n- [ ] Two\n")
        let dropped = Note(relativePath: "Archive/Dropped.md", kind: .archive,
                           text: "---\ntitle: Dropped\ntype: project\nstatus: archived\ngoal: G\n---\n- [ ] Never started\n")
        let progress = NoteIndex(notes: [goal, live, dropped]).progress(of: goal)
        XCTAssertEqual(progress.projectsTotal, 1)
        XCTAssertEqual(progress.percent, 50)
    }

    func testSearchUnderstandsGoals() {
        XCTAssertEqual(SearchQuery.parse("type:goal").kinds, [.goal])
        XCTAssertEqual(SearchQuery.parse("type:goals").kinds, [.goal])
    }
}

import XCTest
@testable import AMSParaCore

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

    func testSearchUnderstandsGoals() {
        XCTAssertEqual(SearchQuery.parse("type:goal").kinds, [.goal])
        XCTAssertEqual(SearchQuery.parse("type:goals").kinds, [.goal])
    }
}

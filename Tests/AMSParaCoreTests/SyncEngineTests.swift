import XCTest
@testable import AMSParaCore

final class SyncEngineTests: XCTestCase {
    var vault: Vault!
    var store: InMemoryRemindersStore!
    var engine: SyncEngine!
    let fixedNow = DoneStamp.date(from: "2026-09-05 12:00")!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        store = InMemoryRemindersStore(lists: ["Reminders"])
        store.now = { self.fixedNow }
        engine = SyncEngine(vault: vault, store: store, deviceID: "test-device")
        engine.now = { self.fixedNow }
    }

    override func tearDown() {
        removeVault(vault)
    }

    private func writeInbox(_ body: String) throws {
        var inbox = try vault.loadNote(relativePath: "Inbox.md")
        inbox.body = body
        try vault.save(inbox)
    }

    private func inbox() throws -> Note { try vault.loadNote(relativePath: "Inbox.md") }

    // MARK: Note -> Reminders

    func testOpenTasksBecomeRemindersWithIdsAndMarkers() async throws {
        try writeInbox("# Inbox\n\n## Tasks\n\n- [ ] Buy milk >2026-09-08 !!\n- [x] Already done\n")
        let report = try await engine.run()

        XCTAssertEqual(report.remindersCreated, 1)
        XCTAssertEqual(report.idsAssigned, 2)
        let tasks = try inbox().tasks
        XCTAssertNotNil(tasks[0].id)
        XCTAssertNotNil(tasks[1].id)

        let reminders = try await store.reminders(inList: "Inbox")
        XCTAssertEqual(reminders.count, 1)
        let r = reminders[0]
        XCTAssertEqual(r.title, "Buy milk")
        XCTAssertEqual(r.dueDate, DateOnly(year: 2026, month: 9, day: 8))
        XCTAssertEqual(r.priority, 2)
        XCTAssertFalse(r.isCompleted)
        XCTAssertEqual(SyncEngine.markerTaskID(in: r.notes), tasks[0].id)

        // A second run changes nothing.
        let second = try await engine.run()
        XCTAssertEqual(second.changeCount, 0)
        XCTAssertEqual(second.idsAssigned, 0)
    }

    func testProjectNoteMapsToListNamedAfterProject() async throws {
        var project = try vault.createNote(kind: .project, title: "Garden shed")
        project.body += "- [ ] Order timber\n"
        try vault.save(project)
        try await engine.run()
        let lists = try await store.listNames()
        XCTAssertTrue(lists.contains("Garden shed"))
        let reminders = try await store.reminders(inList: "Garden shed")
        XCTAssertEqual(Set(reminders.map(\.title)), ["Define the outcome and the first step", "Order timber"])
    }

    func testRemindersListFrontmatterOverridesListName() async throws {
        var project = try vault.createNote(kind: .project, title: "Garden shed", extraFrontmatter: [("reminders-list", "Home")])
        project.body = "- [ ] Order timber\n"
        try vault.save(project)
        try await engine.run()
        let actual1 = try await store.reminders(inList: "Home").map(\.title)
        XCTAssertEqual(actual1, ["Order timber"])
    }

    func testEditingTaskInNoteUpdatesReminder() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        var note = try inbox()
        var task = note.tasks[0]
        task.title = "Buy oat milk"
        task.dueDate = DateOnly(year: 2026, month: 9, day: 9)
        note.replace(task: task)
        try vault.save(note)

        let report = try await engine.run()
        XCTAssertEqual(report.remindersUpdated, 1)
        let r = try await store.reminders(inList: "Inbox")[0]
        XCTAssertEqual(r.title, "Buy oat milk")
        XCTAssertEqual(r.dueDate, DateOnly(year: 2026, month: 9, day: 9))
    }

    func testCompletingTaskInNoteCompletesReminder() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        var note = try inbox()
        var task = note.tasks[0]
        task.markDone(at: fixedNow)
        note.replace(task: task)
        try vault.save(note)
        try await engine.run()
        let r = try await store.reminders(inList: "Inbox")[0]
        XCTAssertTrue(r.isCompleted)
        XCTAssertEqual(r.completedAt, fixedNow)
    }

    func testDeletingTaskLineDeletesReminder() async throws {
        try writeInbox("- [ ] Buy milk\n- [ ] Keep me\n")
        try await engine.run()
        var note = try inbox()
        note.removeTask(at: 0)
        try vault.save(note)
        let report = try await engine.run()
        XCTAssertEqual(report.remindersDeleted, 1)
        let actual2 = try await store.reminders(inList: "Inbox").map(\.title)
        XCTAssertEqual(actual2, ["Keep me"])
    }

    // MARK: Reminders -> Note

    func testNewReminderIsImportedIntoNote() async throws {
        try writeInbox("# Inbox\n\n## Tasks\n\n- [ ] Existing\n")
        try await engine.run()
        let created = try await store.simulateUserCreate(list: "Inbox", title: "Call dentist", dueDate: DateOnly(year: 2026, month: 9, day: 12), priority: 3)
        let report = try await engine.run()

        XCTAssertEqual(report.tasksCreated, 1)
        let tasks = try inbox().tasks
        XCTAssertEqual(tasks.count, 2)
        let imported = tasks[1]
        XCTAssertEqual(imported.title, "Call dentist")
        XCTAssertEqual(imported.dueDate, DateOnly(year: 2026, month: 9, day: 12))
        XCTAssertEqual(imported.priority, 3)
        XCTAssertNotNil(imported.id)
        XCTAssertEqual(SyncEngine.markerTaskID(in: store.records[created.identifier]?.notes), imported.id)
        XCTAssertTrue(try inbox().body.hasSuffix("- [ ] Existing ^\(tasks[0].id!)\n- [ ] Call dentist !!! >2026-09-12 ^\(imported.id!)\n"))

        let actual3 = try await engine.run().changeCount

        XCTAssertEqual(actual3, 0)
    }

    func testCompletedUnlinkedRemindersAreSkippedByDefault() async throws {
        try writeInbox("")
        try await store.simulateUserCreate(list: "Inbox", title: "Old", completed: true)
        try await engine.run()
        XCTAssertEqual(try inbox().tasks.count, 0)

        var config = vault.config
        config.importCompletedReminders = true
        engine.config = config
        try await engine.run()
        XCTAssertEqual(try inbox().tasks.map(\.status), [.done])
    }

    func testCompletingReminderMarksTaskDone() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        let r = try await store.reminders(inList: "Inbox")[0]
        store.simulateUserEdit(identifier: r.identifier) {
            $0.isCompleted = true
            $0.completedAt = self.fixedNow
        }
        let report = try await engine.run()
        XCTAssertEqual(report.tasksUpdated, 1)
        let task = try inbox().tasks[0]
        XCTAssertEqual(task.status, .done)
        XCTAssertEqual(task.doneStamp, "2026-09-05 12:00")
    }

    func testRenamingReminderUpdatesTask() async throws {
        try writeInbox("- [ ] Buy milk #groceries >2026-09-08\n")
        try await engine.run()
        let r = try await store.reminders(inList: "Inbox")[0]
        store.simulateUserEdit(identifier: r.identifier) { $0.title = "Buy milk and eggs #groceries" }
        try await engine.run()
        let task = try inbox().tasks[0]
        XCTAssertEqual(task.title, "Buy milk and eggs #groceries")
        XCTAssertEqual(task.tags, ["groceries"])
        XCTAssertEqual(task.dueDate, DateOnly(year: 2026, month: 9, day: 8))
        let actual4 = try await engine.run().changeCount
        XCTAssertEqual(actual4, 0)
    }

    func testDeletingReminderCancelsTask() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        let r = try await store.reminders(inList: "Inbox")[0]
        try await store.delete(identifier: r.identifier)
        let report = try await engine.run()
        XCTAssertEqual(report.tasksCancelled, 1)
        XCTAssertEqual(try inbox().tasks[0].status, .cancelled)
        let actual5 = try await store.reminders(inList: "Inbox").count
        XCTAssertEqual(actual5, 0)
    }

    // MARK: Conflicts and edge cases

    func testConflictDefaultsToNoteWins() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        var note = try inbox()
        var task = note.tasks[0]
        task.title = "Buy milk (note)"
        note.replace(task: task)
        try vault.save(note)
        let r = try await store.reminders(inList: "Inbox")[0]
        store.simulateUserEdit(identifier: r.identifier) { $0.title = "Buy milk (reminder)" }

        let report = try await engine.run()
        XCTAssertEqual(report.conflicts.count, 1)
        let actual6 = try await store.reminders(inList: "Inbox")[0].title
        XCTAssertEqual(actual6, "Buy milk (note)")
        XCTAssertEqual(try inbox().tasks[0].title, "Buy milk (note)")
    }

    func testConflictReminderWins() async throws {
        var config = vault.config
        config.conflictPolicy = .reminderWins
        engine.config = config
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        var note = try inbox()
        var task = note.tasks[0]
        task.title = "Buy milk (note)"
        note.replace(task: task)
        try vault.save(note)
        let r = try await store.reminders(inList: "Inbox")[0]
        store.simulateUserEdit(identifier: r.identifier) { $0.title = "Buy milk (reminder)" }

        try await engine.run()
        XCTAssertEqual(try inbox().tasks[0].title, "Buy milk (reminder)")
    }

    func testFreshDeviceRelinksThroughMarkerInsteadOfDuplicating() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        let actual7 = try await store.reminders(inList: "Inbox").count
        XCTAssertEqual(actual7, 1)

        // Same vault and Reminders, but no sync state (e.g. a second Mac).
        let other = SyncEngine(vault: vault, store: store, deviceID: "second-device")
        let report = try await other.run()
        XCTAssertEqual(report.remindersCreated, 0)
        XCTAssertEqual(report.changeCount, 0)
        let actual8 = try await store.reminders(inList: "Inbox").count
        XCTAssertEqual(actual8, 1)
        XCTAssertEqual(vault.loadSyncState(deviceID: "second-device").links.count, 1)
    }

    func testMarkedReminderWhoseTaskDisappearedIsDeleted() async throws {
        try writeInbox("- [ ] Buy milk\n")
        try await engine.run()
        try writeInbox("")
        let other = SyncEngine(vault: vault, store: store, deviceID: "second-device")
        let report = try await other.run()
        XCTAssertEqual(report.remindersDeleted, 1)
        let actual9 = try await store.reminders(inList: "Inbox").count
        XCTAssertEqual(actual9, 0)
    }

    func testNotesWithSyncFalseAndArchivedAreIgnored() async throws {
        var off = try vault.createNote(kind: .project, title: "Private", extraFrontmatter: [("sync", "false")])
        off.body = "- [ ] Secret\n"
        try vault.save(off)
        var archived = try vault.createNote(kind: .project, title: "Old", extraFrontmatter: [("status", "archived")])
        archived.body = "- [ ] Stale\n"
        try vault.save(archived)
        let report = try await engine.run()
        XCTAssertEqual(report.remindersCreated, 0)
        XCTAssertEqual(report.notesSynced, 1)
        let lists = try await store.listNames()
        XCTAssertFalse(lists.contains("Private"))
        XCTAssertFalse(lists.contains("Old"))
    }

    func testArchivingProjectKeepsRemindersUntouched() async throws {
        var project = try vault.createNote(kind: .project, title: "Shed")
        project.body = "- [ ] Order timber\n"
        try vault.save(project)
        try await engine.run()
        try vault.archive(try vault.loadNote(relativePath: project.relativePath))
        let report = try await engine.run()
        XCTAssertEqual(report.remindersDeleted, 0)
        let actual10 = try await store.reminders(inList: "Shed").count
        XCTAssertEqual(actual10, 1)
    }

    func testTaskMovedBetweenNotesMovesReminder() async throws {
        try writeInbox("- [ ] Order timber\n")
        try await engine.run()
        let taskLine = try inbox().lines[0]
        try writeInbox("")
        var project = try vault.createNote(kind: .project, title: "Shed")
        project.body = taskLine + "\n"
        try vault.save(project)

        let report = try await engine.run()
        XCTAssertEqual(report.remindersDeleted, 0)
        XCTAssertEqual(report.remindersCreated, 0)
        let actual11 = try await store.reminders(inList: "Inbox").count
        XCTAssertEqual(actual11, 0)
        let actual12 = try await store.reminders(inList: "Shed").map(\.title)
        XCTAssertEqual(actual12, ["Order timber"])
    }

    func testMarkerHelpersPreserveUserNotes() {
        let notes = SyncEngine.notes("Bring the receipt", withMarkerFor: "tabc123")
        XCTAssertEqual(notes, "Bring the receipt\n\nams-para:^tabc123")
        XCTAssertEqual(SyncEngine.markerTaskID(in: notes), "tabc123")
        XCTAssertEqual(SyncEngine.notes(notes, withMarkerFor: "tabc123"), notes)
        XCTAssertEqual(SyncEngine.notes(notes, withMarkerFor: "tdef456"), "Bring the receipt\n\nams-para:^tdef456")
        XCTAssertNil(SyncEngine.markerTaskID(in: nil))
    }
}

final class DailyNoteSyncTests: XCTestCase {
    var vault: Vault!
    var store: InMemoryRemindersStore!
    var engine: SyncEngine!
    let fixedNow = DoneStamp.date(from: "2026-09-05 12:00")!
    let today = DateOnly(year: 2026, month: 9, day: 5)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        store = InMemoryRemindersStore(lists: ["Reminders"])
        store.now = { self.fixedNow }
        engine = SyncEngine(vault: vault, store: store, deviceID: "test-device")
        engine.now = { self.fixedNow }
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testTasksInDailyNotesShareOneList() async throws {
        var yesterday = try vault.dailyNote(for: today.adding(days: -1))
        yesterday.body += "- [ ] From yesterday\n"
        try vault.save(yesterday)
        var todayNote = try vault.dailyNote(for: today)
        todayNote.body += "- [ ] From today >2026-09-05\n"
        try vault.save(todayNote)

        let report = try await engine.run()
        XCTAssertEqual(report.remindersCreated, 2)
        XCTAssertTrue(report.warnings.isEmpty)
        let titles = try await store.reminders(inList: "Daily Notes").map(\.title)
        XCTAssertEqual(Set(titles), ["From yesterday", "From today"])
    }

    func testReminderAddedToDailyListLandsInTodaysNote() async throws {
        try await engine.run()
        XCTAssertFalse(vault.dailyNoteExists(for: today))
        try await store.simulateUserCreate(list: "Daily Notes", title: "Call the plumber")
        let report = try await engine.run()
        XCTAssertEqual(report.tasksCreated, 1)
        XCTAssertTrue(vault.dailyNoteExists(for: today))
        let note = try vault.dailyNote(for: today)
        XCTAssertEqual(note.tasks.map(\.title), ["Call the plumber"])
        XCTAssertNotNil(note.tasks[0].id)
        let second = try await engine.run()
        XCTAssertEqual(second.changeCount, 0)
    }

    func testDailySyncCanBeSwitchedOff() async throws {
        var config = vault.config
        config.syncDailyNotes = false
        engine.config = config
        var note = try vault.dailyNote(for: today)
        note.body += "- [ ] Private\n"
        try vault.save(note)
        let report = try await engine.run()
        XCTAssertEqual(report.remindersCreated, 0)
        let lists = try await store.listNames()
        XCTAssertFalse(lists.contains("Daily Notes"))
    }
}

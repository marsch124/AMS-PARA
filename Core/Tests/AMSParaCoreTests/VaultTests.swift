import XCTest
@testable import AMSParaCore

final class VaultTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testBootstrapCreatesLayout() throws {
        let fm = FileManager.default
        for folder in ["Projects", "Areas", "Resources", "Archive", "Templates"] {
            XCTAssertTrue(fm.fileExists(atPath: vault.rootURL.appendingPathComponent(folder).path), folder)
        }
        XCTAssertTrue(fm.fileExists(atPath: vault.rootURL.appendingPathComponent("Inbox.md").path))
        XCTAssertTrue(fm.fileExists(atPath: vault.configURL.path))
        let inbox = try vault.loadNote(relativePath: "Inbox.md")
        XCTAssertEqual(inbox.kind, .inbox)
        XCTAssertEqual(inbox.title, "Inbox")
    }

    func testCreateNoteUsesTemplateAndFrontmatter() throws {
        let note = try vault.createNote(kind: .project, title: "Website relaunch", extraFrontmatter: [("area", "Business")])
        XCTAssertEqual(note.relativePath, "Projects/Website relaunch.md")
        XCTAssertEqual(note.title, "Website relaunch")
        XCTAssertEqual(note.frontmatter.string("type"), "project")
        XCTAssertEqual(note.frontmatter.string("area"), "Business")
        XCTAssertEqual(note.frontmatter.string("created"), DateOnly.today().description)
        XCTAssertTrue(note.body.contains("# Website relaunch"))
        XCTAssertEqual(note.tasks.count, 1)

        let reloaded = try vault.loadNote(relativePath: note.relativePath)
        XCTAssertEqual(reloaded.text, note.text)
        XCTAssertThrowsError(try vault.createNote(kind: .project, title: "Website relaunch"))
    }

    func testSanitizesFileNames() throws {
        XCTAssertEqual(Vault.sanitizeFileName("Plan: A/B test?"), "Plan A B test")
        let note = try vault.createNote(kind: .resource, title: "Plan: A/B test?")
        XCTAssertEqual(note.relativePath, "Resources/Plan A B test.md")
        XCTAssertEqual(note.title, "Plan: A/B test?")
    }

    func testEnumeratesNotesRecursivelyAndSkipsTemplates() throws {
        _ = try vault.createNote(kind: .project, title: "P1")
        _ = try vault.createNote(kind: .area, title: "A1")
        let nested = vault.rootURL.appendingPathComponent("Resources/Books/Deep Work.md")
        try FileManager.default.createDirectory(at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\ntitle: Deep Work\ntype: resource\n---\n# Deep Work\n".write(to: nested, atomically: true, encoding: .utf8)

        let all = try vault.allNotes()
        XCTAssertEqual(Set(all.map(\.relativePath)), ["Inbox.md", "Projects/P1.md", "Areas/A1.md", "Resources/Books/Deep Work.md"])
        XCTAssertEqual(try vault.notes(kind: .resource).map(\.title), ["Deep Work"])
        XCTAssertEqual(vault.kind(forRelativePath: "Resources/Books/Deep Work.md"), .resource)
    }

    func testTrashRemovesNoteFile() throws {
        let note = try vault.createNote(kind: .goal, title: "Old goal")
        let path = vault.rootURL.appendingPathComponent(note.relativePath).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        try vault.trash(note)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        XCTAssertFalse(try vault.allNotes().contains { $0.relativePath == note.relativePath })
    }

    func testArchiveMovesNoteAndDisablesSync() throws {
        let note = try vault.createNote(kind: .project, title: "Old")
        let archived = try vault.archive(note)
        XCTAssertEqual(archived.relativePath, "Archive/Projects/Old.md")
        XCTAssertEqual(archived.kind, .archive)
        XCTAssertFalse(archived.isSyncEnabled)
        XCTAssertTrue(archived.isArchived)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.url(for: note.relativePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.url(for: archived.relativePath).path))
    }

    func testIndexBacklinksResourcesAndOpenTasks() throws {
        let area = try vault.createNote(kind: .area, title: "Health")
        var project = try vault.createNote(kind: .project, title: "Run 10k", extraFrontmatter: [("area", "Health")])
        project.body += "\n- [ ] Buy shoes >2026-09-01\n- [ ] Register !!\n- [x] Done thing\n"
        try vault.save(project)
        var resource = try vault.createNote(kind: .resource, title: "Training plan")
        resource.body += "\nSupports [[Run 10k]].\n"
        try vault.save(resource)

        let index = NoteIndex(notes: try vault.allNotes())
        XCTAssertEqual(index.projects(in: area).map(\.title), ["Run 10k"])
        XCTAssertEqual(index.resources(for: project).map(\.title), ["Training plan"])
        XCTAssertEqual(index.backlinks(to: project).map(\.title), ["Training plan"])
        XCTAssertEqual(index.note(matching: "run 10k")?.relativePath, "Projects/Run 10k.md")

        let open = index.openTasks()
        XCTAssertEqual(open.map(\.task.title), ["Buy shoes", "Register", "Define the outcome and the first step"])
        let due = index.openTasks(dueOnOrBefore: DateOnly(year: 2026, month: 9, day: 1))
        XCTAssertEqual(due.map(\.task.title), ["Buy shoes"])
    }

    func testSyncStateRoundTrip() throws {
        var state = SyncState()
        state.links["t1"] = TaskLink(taskID: "t1", reminderID: "r1", notePath: "Inbox.md", listName: "Inbox",
                                     lastTaskFingerprint: "a", lastReminderFingerprint: "b", lastSyncedAt: Date(timeIntervalSince1970: 1_000))
        try vault.save(syncState: state, deviceID: "mac/1")
        XCTAssertEqual(vault.loadSyncState(deviceID: "mac/1"), state)
        XCTAssertEqual(vault.loadSyncState(deviceID: "other"), SyncState())
    }
}

final class DailyNoteTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testDailyNoteIsCreatedOnDemandInCalendarFolder() throws {
        let date = DateOnly(year: 2026, month: 9, day: 5)
        XCTAssertFalse(vault.dailyNoteExists(for: date))
        let note = try vault.dailyNote(for: date)
        XCTAssertEqual(note.relativePath, "Calendar/20260905.md")
        XCTAssertEqual(note.kind, .daily)
        XCTAssertEqual(note.dailyDate, date)
        XCTAssertTrue(note.body.contains("## Tasks"))
        XCTAssertTrue(vault.dailyNoteExists(for: date))
        XCTAssertEqual(vault.kind(forRelativePath: "Calendar/20260905.md"), .daily)

        // Loading again returns the saved file rather than a fresh template.
        var edited = note
        edited.body += "- [ ] Water the plants\n"
        try vault.save(edited)
        XCTAssertEqual(try vault.dailyNote(for: date).tasks.map(\.title), ["Water the plants"])
    }

    func testDailyNotesAreListedNewestFirst() throws {
        _ = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 3))
        _ = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 5))
        _ = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 4))
        XCTAssertEqual(try vault.notes(kind: .daily).map(\.fileName), ["20260905", "20260904", "20260903"])
        let index = NoteIndex(notes: try vault.allNotes())
        XCTAssertEqual(index.dailyNotes.map(\.fileName), ["20260905", "20260904", "20260903"])
        XCTAssertEqual(index.dailyNote(for: DateOnly(year: 2026, month: 9, day: 4))?.relativePath, "Calendar/20260904.md")
    }

    func testDailyFileNameParsing() {
        XCTAssertEqual(Note.dailyDate(fromFileName: "20261231"), DateOnly(year: 2026, month: 12, day: 31))
        XCTAssertNil(Note.dailyDate(fromFileName: "2026-12-31"))
        XCTAssertNil(Note.dailyDate(fromFileName: "20261301"))
        XCTAssertEqual(Note.dailyFileName(for: DateOnly(year: 2026, month: 1, day: 7)), "20260107")
    }

    func testDailyNotesCannotBeCreatedByTitleOrArchived() throws {
        XCTAssertThrowsError(try vault.createNote(kind: .daily, title: "x"))
        let note = try vault.dailyNote(for: DateOnly(year: 2026, month: 9, day: 5))
        XCTAssertEqual(try vault.archive(note).relativePath, note.relativePath)
    }
}

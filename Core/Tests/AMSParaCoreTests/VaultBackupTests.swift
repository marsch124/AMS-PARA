import XCTest
@testable import AMSParaCore

final class VaultBackupTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testBackupCopiesNotesAndSkipsItself() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "- [ ] Book the hotel\n"
        try vault.save(note)

        let backup = try XCTUnwrap(try vault.makeBackup(reason: "manual"))
        XCTAssertEqual(backup.reason, "manual")
        XCTAssertTrue(backup.noteCount >= 2, "the project and the inbox")
        let copied = vault.backupsURL.appendingPathComponent(backup.folderName).appendingPathComponent("Projects/Race.md")
        XCTAssertTrue(try String(contentsOf: copied, encoding: .utf8).contains("Book the hotel"))
        // The backup folder itself is never copied into the next backup.
        let second = try vault.makeBackup(reason: "manual", now: Date().addingTimeInterval(60))
        XCTAssertNil(second, "nothing changed, so no second copy")
        XCTAssertEqual(vault.backups().count, 1)
    }

    func testBackupIsMadeAgainOnceSomethingChanged() throws {
        _ = try vault.makeBackup(reason: "daily")
        var note = try vault.createNote(kind: .project, title: "New")
        note.body = "changed"
        try vault.save(note)
        let second = try vault.makeBackup(reason: "sync", now: Date().addingTimeInterval(120))
        XCTAssertNotNil(second)
        XCTAssertEqual(vault.backups().count, 2)
        XCTAssertEqual(vault.backups().first?.reason, "sync", "newest first")
    }

    func testOnlyTheNewestBackupsAreKept() throws {
        for i in 0..<5 {
            var note = try vault.loadNote(relativePath: "Inbox.md")
            note.body = "- [ ] Step \(i)\n"
            note.modifiedAt = nil
            try vault.save(note)
            let made = try vault.makeBackup(reason: "daily", keeping: 3, now: Date().addingTimeInterval(Double(i) * 120))
            XCTAssertNotNil(made, "the vault changed in round \(i), so a copy is due")
        }
        XCTAssertEqual(vault.backups().count, 3)
    }

    func testRestorePutsTheOldNoteBackAndKeepsNewerOnes() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "first version"
        note = try vault.save(note)
        let backup = try XCTUnwrap(try vault.makeBackup(reason: "manual"))
        let inBackup = vault.backupsURL.appendingPathComponent(backup.folderName).appendingPathComponent("Projects/Race.md")
        XCTAssertTrue(try String(contentsOf: inBackup, encoding: .utf8).contains("first version"), "the backup holds the old text")

        note.body = "second version"
        note.modifiedAt = nil
        try vault.save(note)
        XCTAssertTrue(try vault.loadNote(relativePath: "Projects/Race.md").body.contains("second version"))
        let later = try vault.createNote(kind: .project, title: "Later")

        let written = try vault.restore(backup, now: Date().addingTimeInterval(300))
        XCTAssertTrue(written > 0)
        XCTAssertTrue(try vault.loadNote(relativePath: "Projects/Race.md").body.contains("first version"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.url(for: later.relativePath).path),
                      "a note made after the backup is left alone")
        XCTAssertTrue(vault.backups().contains { $0.reason == "before restore" })
    }

    func testCopyContentsGivesAWorkingVaultCopy() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "- [ ] Book the hotel\n"
        try vault.save(note)
        _ = try vault.makeBackup(reason: "manual")

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("copy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: destination) }
        try vault.copyContents(to: destination)
        let copy = try Vault(rootURL: destination)
        XCTAssertEqual(try copy.allNotes().count, try vault.allNotes().count)
        XCTAssertTrue(copy.backups().isEmpty, "backups are not copied along")
    }
}

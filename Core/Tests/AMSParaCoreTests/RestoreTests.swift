import XCTest
@testable import AMSParaCore

/// Backups have been made daily since build 44 and never restored. These tests are the first
/// time the way back is exercised at all.
final class RestoreTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
        vault = nil
    }

    func testRestoreBringsBackADeletedNoteAndKeepsANewerOne() throws {
        let roof = try vault.createNote(kind: .project, title: "Roof")
        let backup = try XCTUnwrap(try vault.makeBackup(reason: "test"))

        try vault.trash(roof)
        let later = try vault.createNote(kind: .project, title: "Garden")

        let result = try vault.restore(backup)

        XCTAssertTrue(result.isComplete)
        let paths = try vault.allNotes().map(\.relativePath)
        XCTAssertTrue(paths.contains(roof.relativePath), "the deleted note did not come back")
        XCTAssertTrue(paths.contains(later.relativePath), "a note made after the backup was removed")
    }

    func testRestoreUndoesAnEditButKeepsACopyOfIt() throws {
        var note = try vault.createNote(kind: .project, title: "Roof")
        note.text += "\n- [ ] The version in the backup\n"
        note = try vault.save(note)
        let backup = try XCTUnwrap(try vault.makeBackup(reason: "test"))

        note.text = note.text.replacingOccurrences(of: "The version in the backup", with: "What I typed today")
        _ = try vault.save(note)

        _ = try vault.restore(backup)

        let restored = try vault.loadNote(relativePath: note.relativePath)
        XCTAssertTrue(restored.text.contains("The version in the backup"))
        // The state before the restore is itself a backup, so today's text is not gone.
        let safetyCopy = try XCTUnwrap(vault.backups().first { $0.reason == "before restore" })
        let kept = try String(contentsOf: vault.backupsURL.appendingPathComponent(safetyCopy.folderName)
            .appendingPathComponent(note.relativePath), encoding: .utf8)
        XCTAssertTrue(kept.contains("What I typed today"))
    }

    func testFilesThatCannotBeWrittenDoNotStopTheRest() throws {
        try XCTSkipIf(getuid() == 0, "running as root, so a folder cannot be made read-only")
        let roof = try vault.createNote(kind: .project, title: "Roof")
        let backup = try XCTUnwrap(try vault.makeBackup(reason: "test"))
        try "changed".write(to: vault.url(for: roof.relativePath), atomically: true, encoding: .utf8)
        // The Projects folder cannot be written into, so those notes cannot be put back.
        let projects = vault.rootURL.appendingPathComponent(vault.config.projectsFolder)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: projects.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: projects.path)
        }

        let result = try vault.restore(backup)

        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(result.failed.contains(roof.relativePath))
        XCTAssertGreaterThan(result.written, 0, "one unwritable folder stopped the whole restore")
    }

    func testRestoringABackupThatIsGoneChangesNothing() throws {
        let note = try vault.createNote(kind: .project, title: "Roof")
        let missing = VaultBackup(folderName: "2026-01-01 0900~test", date: Date(), noteCount: 3, reason: "test")

        XCTAssertThrowsError(try vault.restore(missing))
        XCTAssertTrue(try vault.allNotes().contains { $0.relativePath == note.relativePath })
    }

    func testTheDeletedFolderIsInTheBackupToo() throws {
        let note = try vault.createNote(kind: .project, title: "Roof")
        try vault.trash(note)

        let backup = try XCTUnwrap(try vault.makeBackup(reason: "test"))
        let deleted = try XCTUnwrap(vault.deletedNotes().first)
        let inBackup = vault.backupsURL.appendingPathComponent(backup.folderName)
            .appendingPathComponent(Vault.stateFolderName)
            .appendingPathComponent("Deleted")
            .appendingPathComponent(deleted.fileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: inBackup.path),
                      "a note in Deleted is not in the backup, so emptying Deleted would be final")
    }

    func testAnUnreadableNoteDoesNotCostTheOthersTheirBackup() throws {
        try XCTSkipIf(getuid() == 0, "running as root, so permissions cannot be used to make a file unreadable")
        _ = try vault.createNote(kind: .project, title: "Roof")
        let locked = try vault.createNote(kind: .project, title: "Garden")
        try FileManager.default.setAttributes([.posixPermissions: 0],
                                              ofItemAtPath: vault.url(for: locked.relativePath).path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                   ofItemAtPath: vault.url(for: locked.relativePath).path)
        }

        let backup = try XCTUnwrap(try vault.makeBackup(reason: "test"))
        let folder = vault.backupsURL.appendingPathComponent(backup.folderName)

        XCTAssertGreaterThan(backup.noteCount, 0, "one unreadable file cost the whole backup")
        let skipped = try String(contentsOf: folder.appendingPathComponent("skipped.txt"), encoding: .utf8)
        XCTAssertTrue(skipped.contains(locked.relativePath), "the backup does not say what it is missing")
    }
}

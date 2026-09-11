import XCTest
@testable import ParagonCore

final class DeletedNotesTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
        vault = nil
    }

    func testTrashingKeepsTheNoteInTheDeletedFolder() throws {
        let note = try vault.createNote(kind: .project, title: "Old project")

        try vault.trash(note)

        let deleted = vault.deletedNotes()
        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(deleted.first?.title, "Old project")
        XCTAssertEqual(deleted.first?.kind, .project)
        XCTAssertEqual(deleted.first?.originalPath, note.relativePath)
        XCTAssertFalse(try vault.allNotes().contains { $0.relativePath == note.relativePath })
    }

    func testPuttingBackReturnsItToWhereItWas() throws {
        let note = try vault.createNote(kind: .area, title: "Health")
        try vault.trash(note)

        let restored = try vault.restore(try XCTUnwrap(vault.deletedNotes().first))

        XCTAssertEqual(restored.relativePath, note.relativePath)
        XCTAssertEqual(restored.title, "Health")
        XCTAssertNil(restored.frontmatter.string("deleted"))
        XCTAssertNil(restored.frontmatter.string("deleted-from"))
        XCTAssertTrue(vault.deletedNotes().isEmpty)
        XCTAssertTrue(try vault.allNotes().contains { $0.relativePath == note.relativePath })
    }

    func testPuttingBackNeverOverwritesANoteMadeSince() throws {
        let note = try vault.createNote(kind: .area, title: "Health")
        try vault.trash(note)
        _ = try vault.createNote(kind: .area, title: "Health")

        let restored = try vault.restore(try XCTUnwrap(vault.deletedNotes().first))

        XCTAssertEqual(restored.relativePath, "Areas/Health (restored).md")
        XCTAssertTrue(try vault.allNotes().contains { $0.relativePath == "Areas/Health.md" })
    }

    func testTwoNotesDeletedAtOnceBothSurvive() throws {
        let first = try vault.createNote(kind: .resource, title: "One")
        let second = try vault.createNote(kind: .resource, title: "Two")
        let moment = Date()

        try vault.moveToDeleted(first, at: moment)
        try vault.moveToDeleted(second, at: moment)

        XCTAssertEqual(Set(vault.deletedNotes().map(\.title)), ["One", "Two"])
    }

    func testDeleteForGoodAndTheAgeLimit() throws {
        let note = try vault.createNote(kind: .goal, title: "Old goal")
        try vault.moveToDeleted(note, at: Date().addingTimeInterval(-40 * 86_400))
        let old = try vault.createNote(kind: .goal, title: "Older goal")
        try vault.moveToDeleted(old, at: Date())

        vault.purgeDeleted(olderThan: 30)
        XCTAssertEqual(vault.deletedNotes().map(\.title), ["Older goal"])

        try vault.purge(try XCTUnwrap(vault.deletedNotes().first))
        XCTAssertTrue(vault.deletedNotes().isEmpty)
    }
}

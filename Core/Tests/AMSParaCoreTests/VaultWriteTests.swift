import XCTest
@testable import AMSParaCore

/// A change that touches several notes cannot be one atomic write. These tests are about the
/// next best thing: a failure that leaves something visible rather than something missing.
final class VaultWriteTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
        vault = nil
    }

    // MARK: Writing several notes

    func testSaveEachSkipsTheNotesThatNeedNoChange() throws {
        let a = try vault.createNote(kind: .project, title: "Roof")
        let b = try vault.createNote(kind: .project, title: "Garden")

        let result = vault.saveEach([a, b]) { note in
            guard note.displayTitle == "Roof" else { return nil }
            var updated = note
            updated.frontmatter.set("status", "active")
            return updated
        }

        XCTAssertEqual(result.saved, [a.relativePath])
        XCTAssertTrue(result.failed.isEmpty)
        XCTAssertTrue(result.isComplete)
    }

    func testAnOutsideEditIsMergedRatherThanRefused() throws {
        let note = try vault.createNote(kind: .project, title: "Roof")
        // The other device wrote the file after we read it.
        try changeOnDisk(note.relativePath) { $0 + "\n- [ ] Ask the roofer\n" }

        let result = vault.saveEach([note]) { note in
            var updated = note
            updated.frontmatter.set("status", "active")
            return updated
        }

        XCTAssertEqual(result.saved, [note.relativePath])
        XCTAssertTrue(result.failed.isEmpty)
        let onDisk = try vault.loadNote(relativePath: note.relativePath)
        XCTAssertEqual(onDisk.frontmatter.string("status"), "active", "our change was dropped")
        XCTAssertTrue(onDisk.text.contains("Ask the roofer"), "the other device's change was overwritten")
    }

    func testANoteThatCannotBeWrittenIsReportedRatherThanPassedOver() throws {
        let note = try vault.createNote(kind: .project, title: "Roof")
        // A folder where the file was: it can be neither read nor written.
        try FileManager.default.removeItem(at: vault.url(for: note.relativePath))
        try FileManager.default.createDirectory(at: vault.url(for: note.relativePath), withIntermediateDirectories: true)

        let result = vault.saveEach([note]) { note in
            var updated = note
            updated.frontmatter.set("status", "active")
            return updated
        }

        XCTAssertEqual(result.failed, [note.relativePath])
        XCTAssertTrue(result.saved.isEmpty)
        XCTAssertFalse(result.isComplete)
    }

    // MARK: Moving a task

    func testMovingATaskWritesTheTargetFirstSoItIsNeverLost() throws {
        var source = try vault.createNote(kind: .project, title: "Kitchen")
        source.append(task: TaskItem(title: "Call the roofer"))
        source = try vault.save(source)
        let target = try vault.createNote(kind: .project, title: "Roof")
        let task = try XCTUnwrap(source.tasks.first)

        let move = try vault.move(task: task, from: source, to: target)

        XCTAssertFalse(move.leftInSource)
        XCTAssertTrue(move.target.text.contains("Call the roofer"))
        XCTAssertFalse(move.source.text.contains("Call the roofer"))
        let onDisk = try vault.loadNote(relativePath: source.relativePath)
        XCTAssertFalse(onDisk.text.contains("Call the roofer"))
    }

    func testATaskLeftInBothPlacesIsSaidSoRatherThanLost() throws {
        var source = try vault.createNote(kind: .project, title: "Garden")
        source.append(task: TaskItem(title: "Order gravel"))
        source = try vault.save(source)
        let target = try vault.createNote(kind: .project, title: "Roof")
        let task = try XCTUnwrap(source.tasks.first)
        // The source is rewritten elsewhere with the task on a different line, so taking it out
        // of what is now on disk cannot work either.
        try changeOnDisk(source.relativePath) { text in
            text.replacingOccurrences(of: "- [ ] Order gravel", with: "- [ ] Book the digger\n- [ ] Order gravel")
        }

        let move = try vault.move(task: task, from: source, to: target)

        XCTAssertTrue(move.leftInSource)
        let targetOnDisk = try vault.loadNote(relativePath: target.relativePath)
        XCTAssertTrue(targetOnDisk.text.contains("Order gravel"), "the task reached neither note")
        let sourceOnDisk = try vault.loadNote(relativePath: source.relativePath)
        XCTAssertTrue(sourceOnDisk.text.contains("Book the digger"), "the other change was overwritten")
    }

    func testMovingATaskThatIsNoLongerThereChangesNothing() throws {
        let source = try vault.createNote(kind: .project, title: "Garden")
        let target = try vault.createNote(kind: .project, title: "Roof")

        XCTAssertThrowsError(try vault.move(task: TaskItem(title: "Ghost"), from: source, to: target)) { error in
            XCTAssertEqual(error as? VaultError, .taskNotFound("Ghost"))
        }
        let targetOnDisk = try vault.loadNote(relativePath: target.relativePath)
        XCTAssertFalse(targetOnDisk.text.contains("Ghost"))
    }

    // MARK: Renaming with the links that point at it

    func testRenamingFollowsTheLinksAndReportsTheOnesItCouldNot() throws {
        let area = try vault.createNote(kind: .area, title: "Health")
        let good = try vault.createNote(kind: .project, title: "Knee", extraFrontmatter: [("area", "Health")])
        let broken = try vault.createNote(kind: .project, title: "Sleep", extraFrontmatter: [("area", "Health")])
        // This one cannot be written when the rename comes round to it.
        try FileManager.default.removeItem(at: vault.url(for: broken.relativePath))
        try FileManager.default.createDirectory(at: vault.url(for: broken.relativePath), withIntermediateDirectories: true)

        let result = try vault.rename(area, to: "Fitness", updating: [good, broken])

        XCTAssertEqual(result.renamed.displayTitle, "Fitness")
        XCTAssertEqual(result.staleLinks, [broken.relativePath])
        let updated = try vault.loadNote(relativePath: good.relativePath)
        XCTAssertEqual(updated.frontmatter.string("area"), "Fitness")
    }

    func testANameThatIsAlreadyTakenLeavesEveryLinkAlone() throws {
        let area = try vault.createNote(kind: .area, title: "Health")
        _ = try vault.createNote(kind: .area, title: "Fitness")
        let project = try vault.createNote(kind: .project, title: "Knee", extraFrontmatter: [("area", "Health")])

        XCTAssertThrowsError(try vault.rename(area, to: "Fitness", updating: [project]))

        let untouched = try vault.loadNote(relativePath: project.relativePath)
        XCTAssertEqual(untouched.frontmatter.string("area"), "Health")
    }

    // MARK: Helpers

    /// Rewrites a note's file behind the app's back, as the other device would.
    private func changeOnDisk(_ relativePath: String, _ change: (String) -> String) throws {
        let url = vault.url(for: relativePath)
        let text = try String(contentsOf: url, encoding: .utf8)
        try change(text).write(to: url, atomically: true, encoding: .utf8)
        // The conflict check works in whole seconds, so the file has to be visibly newer.
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)],
                                              ofItemAtPath: url.path)
    }
}

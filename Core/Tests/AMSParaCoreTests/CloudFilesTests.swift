import XCTest
@testable import AMSParaCore

/// A file iCloud has not sent to this device yet is a hidden ".Name.md.icloud" stub. These
/// tests are about not mistaking that for "the file is not there".
final class CloudFilesTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
        vault = nil
    }

    func testReadsTheNameOutOfAPlaceholder() {
        XCTAssertEqual(CloudFiles.realName(ofPlaceholder: ".Project.md.icloud"), "Project.md")
        XCTAssertNil(CloudFiles.realName(ofPlaceholder: "Project.md"))
        XCTAssertNil(CloudFiles.realName(ofPlaceholder: ".icloud"))
    }

    func testAPlaceholderCountsAsTheFileBeingThere() throws {
        let url = vault.rootURL.appendingPathComponent("Projects/Roof.md")
        XCTAssertFalse(CloudFiles.exists(url))

        try "".write(to: CloudFiles.placeholderURL(for: url), atomically: true, encoding: .utf8)

        XCTAssertTrue(CloudFiles.exists(url))
    }

    func testBootstrapLeavesATemplateThatIsStillOnItsWay() throws {
        let snippets = vault.templatesURL.appendingPathComponent("\(Snippets.fileName).md")
        try FileManager.default.removeItem(at: snippets)
        try "".write(to: CloudFiles.placeholderURL(for: snippets), atomically: true, encoding: .utf8)

        try vault.bootstrap()

        XCTAssertFalse(FileManager.default.fileExists(atPath: snippets.path),
                       "A default was written over a template iCloud was still sending")
    }

    func testANoteThatIsStillOnItsWayIsNotOverwrittenByANewOne() throws {
        let path = "Projects/Roof.md"
        try "".write(to: CloudFiles.placeholderURL(for: vault.url(for: path)), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try vault.createNote(kind: .project, title: "Roof")) { error in
            XCTAssertEqual(error as? VaultError, .noteAlreadyExists(path))
        }
    }

    func testLoadingAPlaceholderSaysItIsComing() throws {
        let path = "Projects/Roof.md"
        try "".write(to: CloudFiles.placeholderURL(for: vault.url(for: path)), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try vault.loadNote(relativePath: path)) { error in
            XCTAssertEqual(error as? VaultError, .notDownloadedYet(path))
        }
    }

    func testTheDownloadPassFindsPlaceholdersAndIgnoresOrdinaryFiles() throws {
        _ = try vault.createNote(kind: .area, title: "Health")
        let waiting = vault.url(for: "Projects/Roof.md")
        try "".write(to: CloudFiles.placeholderURL(for: waiting), atomically: true, encoding: .utf8)

        XCTAssertEqual(vault.downloadCloudFiles(), ["Projects/Roof.md"])
    }
}

extension CloudFilesTests {
    /// The empty-vault incident: iCloud had every note as a hidden ".Note.md.icloud" stub, the
    /// note listing skipped hidden files, and the app saw a vault with nothing in it — not even
    /// something to report as unreadable.
    func testNotesStillInTheCloudAreCountedRatherThanUnseen() throws {
        let real = try vault.createNote(kind: .project, title: "Roof")
        let waiting = vault.url(for: "Projects/Ridge.md")
        try "".write(to: CloudFiles.placeholderURL(for: waiting), atomically: true, encoding: .utf8)

        let notes = try vault.notes(kind: .project)

        XCTAssertEqual(notes.map(\.relativePath), [real.relativePath], "the readable note was lost")
        XCTAssertEqual(vault.notesWaitingForCloud, ["Projects/Ridge.md"],
                       "a note that is only an iCloud stub was passed over in silence")
    }

    func testAVaultThatIsAllStubsIsNotReportedAsEmpty() throws {
        for name in ["Roof", "Garden", "Kitchen"] {
            let url = vault.url(for: "Projects/\(name).md")
            try "".write(to: CloudFiles.placeholderURL(for: url), atomically: true, encoding: .utf8)
        }

        let notes = try vault.allNotes()

        XCTAssertTrue(notes.filter { $0.kind == .project }.isEmpty)
        XCTAssertEqual(vault.notesWaitingForCloud.count, 3)
        XCTAssertTrue(vault.skippedFiles.isEmpty, "waiting for iCloud is not the same as damaged")
    }
}

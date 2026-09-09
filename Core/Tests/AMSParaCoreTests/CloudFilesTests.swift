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

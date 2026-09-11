import XCTest
@testable import ParagonCore

final class NoteRenameTests: XCTestCase {
    private func note(_ path: String, kind: ParaKind, _ frontmatter: [(String, String)] = [],
                      body: String = "") -> Note {
        var fm = Frontmatter()
        fm.set("title", String(path.split(separator: "/").last!.dropLast(3)))
        fm.set("type", kind.frontmatterType)
        for (key, value) in frontmatter { fm.set(key, value) }
        return Note(relativePath: path, kind: kind, frontmatter: fm, body: body)
    }

    func testFrontmatterReferencesFollowTheNewName() {
        let project = note("Projects/Run a 10k.md", kind: .project, [("area", "Health"), ("goal", "Stay fit")])

        let updated = project.retargeting("Health", to: "Fitness")

        XCTAssertEqual(updated?.area, "Fitness")
        XCTAssertEqual(updated?.goal, "Stay fit")
        XCTAssertNil(project.retargeting("Business", to: "Company"))
    }

    func testWikilinksFollowTheNewNameIncludingAliases() {
        let body = "See [[Health]] and [[health|the health note]], but not [[Healthy eating]].\n"

        let rewritten = Note.rewritingWikilinks(in: body, from: "Health", to: "Fitness")

        XCTAssertEqual(rewritten, "See [[Fitness]] and [[Fitness|the health note]], but not [[Healthy eating]].\n")
    }

    func testTheNotesOwnHeadingIsRenamedButNotItsSections() {
        let area = note("Areas/Health.md", kind: .area, body: "# Health\n\nSome prose.\n\n## Health checks\n")

        let renamed = area.headingRenamed(from: "Health", to: "Fitness")

        XCTAssertTrue(renamed.body.hasPrefix("# Fitness\n"))
        XCTAssertTrue(renamed.body.contains("## Health checks"))
    }

    func testRenamingToTheSameNameChangesNothing() {
        let project = note("Projects/P.md", kind: .project, [("area", "Health")])

        XCTAssertNil(project.retargeting("Health", to: "health"))
    }

    func testVaultRenameMovesTheFileAndKeepsTheRest() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let area = try vault.createNote(kind: .area, title: "Health")

        let renamed = try vault.rename(area, to: "Fitness")

        XCTAssertEqual(renamed.relativePath, "Areas/Fitness.md")
        XCTAssertEqual(renamed.title, "Fitness")
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.url(for: area.relativePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.url(for: renamed.relativePath).path))
    }

    func testVaultRenameRefusesAnExistingName() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let area = try vault.createNote(kind: .area, title: "Health")
        _ = try vault.createNote(kind: .area, title: "Fitness")

        XCTAssertThrowsError(try vault.rename(area, to: "Fitness"))
        XCTAssertThrowsError(try vault.rename(area, to: "   "))
    }
}

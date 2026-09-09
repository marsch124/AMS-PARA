import XCTest
@testable import AMSParaCore

final class SnippetTests: XCTestCase {
    private let text = """
    # Snippets

    Prose above the first heading explains the file and is not a snippet.

    ## Delegate

    - [ ] Ask {{who}} to {{what}} >{{tomorrow}}
        - [ ] Check that {{who}} has it >{{week}}

    ## Errand

    - [ ] {{what}} #errand

    """

    func testEachHeadingIsASnippetAndTheProseIsNot() {
        let snippets = Snippets.parse(text)

        XCTAssertEqual(snippets.map(\.name), ["Delegate", "Errand"])
        XCTAssertEqual(snippets[0].lines.count, 2)
        XCTAssertEqual(snippets[1].lines, ["- [ ] {{what}} #errand"])
    }

    func testItAsksOnlyForWhatTheAppCannotWorkOut() {
        let delegate = Snippets.parse(text)[0]

        XCTAssertEqual(delegate.questions, ["who", "what"])
    }

    func testFillingInDatesAndAnswers() {
        let delegate = Snippets.parse(text)[0]
        let today = DateOnly(year: 2026, month: 9, day: 9)

        let lines = Snippets.filled(delegate, answers: ["who": "Anna", "what": "book the room"], today: today)

        XCTAssertEqual(lines[0], "- [ ] Ask Anna to book the room >2026-09-10")
        XCTAssertEqual(lines[1], "    - [ ] Check that Anna has it >2026-09-16")
    }

    func testAnUnansweredPlaceholderIsLeftAloneRatherThanEmptied() {
        let errand = Snippets.parse(text)[1]

        XCTAssertEqual(Snippets.filled(errand, answers: [:]), ["- [ ] {{what}} #errand"])
    }

    func testTheShippedSnippetsParse() {
        let snippets = Snippets.parse(Templates.snippets)

        XCTAssertEqual(snippets.map(\.name),
                       ["Delegate", "Waiting for", "Meeting", "Decision", "Errand", "Follow up"])
        XCTAssertTrue(snippets.allSatisfy { !$0.lines.isEmpty })
    }

    func testTheVaultFindsThemAndListsItsTemplates() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }

        XCTAssertEqual(vault.snippets().map(\.name).first, "Delegate")
        XCTAssertEqual(vault.templateNames().first, "Project")
        XCTAssertTrue(vault.templateNames().contains(Snippets.fileName))

        try vault.saveTemplate(named: "Project", text: "---\ntitle: {{title}}\n---\n# Mine\n")
        XCTAssertEqual(vault.templateText(named: "Project"), "---\ntitle: {{title}}\n---\n# Mine\n")
    }
}

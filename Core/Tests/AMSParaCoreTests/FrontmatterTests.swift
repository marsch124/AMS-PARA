import XCTest
@testable import AMSParaCore

final class FrontmatterTests: XCTestCase {
    func testParsesScalarsInlineListsAndBlockLists() {
        let text = """
        ---
        title: Website relaunch
        type: project
        status: active
        tags: [web, "marketing, inc"]
        related:
          - Areas/Business
          - "Resources/Brand guide"
        due:
        ---
        # Website relaunch
        Body
        """
        let (fm, body) = Frontmatter.parse(text)
        XCTAssertEqual(fm.string("title"), "Website relaunch")
        XCTAssertEqual(fm.string("type"), "project")
        XCTAssertEqual(fm.list("tags"), ["web", "marketing, inc"])
        XCTAssertEqual(fm.list("related"), ["Areas/Business", "Resources/Brand guide"])
        XCTAssertNil(fm.string("due"))
        XCTAssertEqual(fm.keys, ["title", "type", "status", "tags", "related", "due"])
        XCTAssertEqual(body, "# Website relaunch\nBody")
    }

    func testTextWithoutFrontmatterIsAllBody() {
        let (fm, body) = Frontmatter.parse("# Hello\n")
        XCTAssertTrue(fm.isEmpty)
        XCTAssertEqual(body, "# Hello\n")
    }

    func testRoundTripPreservesOrderAndQuotesWhereNeeded() {
        var fm = Frontmatter()
        fm.set("title", "Plan: phase 2")
        fm.set("type", "project")
        fm.set("tags", list: ["a", "b c"])
        let serialized = fm.serialized()
        XCTAssertEqual(serialized, "---\ntitle: \"Plan: phase 2\"\ntype: project\ntags: [a, b c]\n---\n")
        let (parsed, _) = Frontmatter.parse(serialized + "body")
        XCTAssertEqual(parsed, fm)
    }

    func testBoolValues() {
        var fm = Frontmatter()
        fm.set("sync", "false")
        XCTAssertEqual(fm.bool("sync"), false)
        fm.set("sync", "yes")
        XCTAssertEqual(fm.bool("sync"), true)
        XCTAssertNil(fm.bool("missing"))
    }
}

final class FrontmatterEmptyValueTests: XCTestCase {
    func testEmptyValuesRoundTripWithoutBrackets() {
        let (fm, _) = Frontmatter.parse("---\ntitle: X\narea:\ngoal:\ntags: []\n---\n")
        XCTAssertEqual(fm.serialized(), "---\ntitle: X\narea:\ngoal:\ntags:\n---\n")
        XCTAssertNil(fm.string("area"))
        XCTAssertEqual(fm.list("tags"), [])
    }

    func testGoalTypedInsideBracketsWithCommaStaysOneTitle() {
        let note = Note(relativePath: "Projects/P.md", kind: .project,
                        text: "---\ntitle: P\ngoal: [Train for, and finish, the 70.3 (2031)]\n---\n")
        XCTAssertEqual(note.goal, "Train for, and finish, the 70.3 (2031)")
        let plain = Note(relativePath: "Projects/Q.md", kind: .project, text: "---\ntitle: Q\ngoal: Walk the Kungsleden\n---\n")
        XCTAssertEqual(plain.goal, "Walk the Kungsleden")
        let empty = Note(relativePath: "Projects/R.md", kind: .project, text: "---\ntitle: R\ngoal:\n---\n")
        XCTAssertNil(empty.goal)
    }
}

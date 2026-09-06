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

    func testUnknownLinesSurviveARoundTrip() {
        let text = """
        ---
        title: Trip
        # planning notes
        dates:
          start: 2026-01-01
          end: 2026-01-09
        due date: soon
        status: active
        ---
        Body
        """
        var (fm, body) = Frontmatter.parse(text)
        XCTAssertEqual(fm.string("title"), "Trip")
        XCTAssertEqual(fm.string("status"), "active")
        XCTAssertEqual(body, "Body")
        fm.set("status", "done")
        XCTAssertEqual(fm.serialized(), """
        ---
        title: Trip
        # planning notes
        dates:
          start: 2026-01-01
          end: 2026-01-09
        due date: soon
        status: done
        ---

        """)
    }

    func testHorizontalRuleWithProseIsNotFrontmatter() {
        let text = "---\nJust a note that starts with a rule.\nNote: call Anna\n---\nMore"
        let (fm, body) = Frontmatter.parse(text)
        XCTAssertTrue(fm.isEmpty)
        XCTAssertEqual(body, text)
    }

    func testQuotedValuesDoNotGrowBackslashes() {
        var fm = Frontmatter()
        fm.set("title", "Meeting: \"Q3\" plan")
        let once = fm.serialized()
        let (again, _) = Frontmatter.parse(once + "Body")
        XCTAssertEqual(again.string("title"), "Meeting: \"Q3\" plan")
        XCTAssertEqual(again.serialized(), once)
    }

    func testWindowsLineEndingsAndBOMAreRecognised() {
        let text = "\u{FEFF}---\r\ntitle: Windows note\r\nstatus: active\r\n---\r\nBody\r\n"
        let (fm, body) = Frontmatter.parse(text)
        XCTAssertEqual(fm.string("title"), "Windows note")
        XCTAssertEqual(fm.string("status"), "active")
        XCTAssertTrue(body.hasPrefix("Body"))
    }
}

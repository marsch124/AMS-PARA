import XCTest
@testable import ParagonCore

final class MarkdownHighlightTests: XCTestCase {
    private func styles(_ text: String, at needle: String) -> [MarkdownStyle] {
        let range = (text as NSString).range(of: needle)
        XCTAssertNotEqual(range.location, NSNotFound, "\(needle) is not in the text")
        return MarkdownHighlight.spans(in: text)
            .filter { NSIntersectionRange($0.range, range).length > 0 }
            .map(\.style)
    }

    func testHeadingsAreSizedAndTheirHashesFade() {
        let text = "# Big\n### Smaller\nplain"
        XCTAssertTrue(styles(text, at: "Big").contains(.heading(level: 1)))
        XCTAssertTrue(styles(text, at: "Smaller").contains(.heading(level: 3)))
        XCTAssertTrue(styles(text, at: "###").contains(.marker))
        XCTAssertTrue(styles(text, at: "plain").isEmpty)
    }

    func testTaskLinesGetABoxDatesPriorityAndTags() {
        let text = "- [ ] Call the bank >2026-09-10 !! #money ^tabc123"
        XCTAssertTrue(styles(text, at: "- [ ]").contains(.marker))
        XCTAssertTrue(styles(text, at: ">2026-09-10").contains(.dueDate))
        XCTAssertTrue(styles(text, at: "!!").contains(.priority))
        XCTAssertTrue(styles(text, at: "#money").contains(.tag))
        XCTAssertTrue(styles(text, at: "^tabc123").contains(.marker))
    }

    func testFinishedTasksAreStruckThrough() {
        let text = "- [x] Buy milk @done(2026-09-06 10:00)"
        XCTAssertTrue(styles(text, at: "Buy milk").contains(.finished))
        XCTAssertTrue(styles(text, at: "@done(2026-09-06 10:00)").contains(.dueDate))
        XCTAssertFalse(styles("- [ ] Buy milk", at: "Buy milk").contains(.finished))
    }

    func testFrontmatterAndCodeBlocksAreOneQuietBlock() {
        let text = "---\ntitle: Race\n---\n# Race\n\n```\nlet x = 1\n```\n"
        XCTAssertTrue(styles(text, at: "title: Race").contains(.frontmatter))
        XCTAssertTrue(styles(text, at: "let x = 1").contains(.code))
        XCTAssertTrue(styles(text, at: "Race\n\n").contains(.heading(level: 1)), "the heading is still a heading")
    }

    func testInlineStylesAndWikilinks() {
        let text = "Some **bold** and *slanted* and `code` and [[Another note]]."
        XCTAssertTrue(styles(text, at: "**bold**").contains(.bold))
        XCTAssertTrue(styles(text, at: "*slanted*").contains(.italic))
        XCTAssertTrue(styles(text, at: "`code`").contains(.code))
        XCTAssertTrue(styles(text, at: "[[Another note]]").contains(.link))
    }

    func testQuotesAndRules() {
        let text = "> A quote\n\n---\n"
        XCTAssertTrue(styles(text, at: "A quote").contains(.quote))
        XCTAssertTrue(styles(text, at: "---").contains(.rule))
    }

    func testEveryRangeStaysInsideTheText() {
        let samples = ["", "\n\n", "# ", "- [ ]", "**", "`", "[[", "---\n---\n", "täsk with émoji 🎉 **bold**",
                       "- [x] Done @done(2026-01-01) ^tabc123 #tag !!! >2026-02-03T09:30"]
        for sample in samples {
            let length = (sample as NSString).length
            for span in MarkdownHighlight.spans(in: sample) {
                XCTAssertGreaterThanOrEqual(span.range.location, 0, sample)
                XCTAssertLessThanOrEqual(NSMaxRange(span.range), length, "\(span) out of \(sample)")
            }
        }
    }
}

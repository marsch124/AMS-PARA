import XCTest
@testable import ParagonCore

final class WikiLinkTests: XCTestCase {
    // MARK: What is being typed

    func testFindsTheLinkBeingTyped() throws {
        let text = "See [[Endu"
        let draft = try XCTUnwrap(WikiLinks.draft(in: text, cursor: text.utf16.count))
        XCTAssertEqual(draft.query, "Endu")
        XCTAssertEqual(draft.start, 4)
    }

    func testBracketsOnTheirOwnOfferEverything() throws {
        let text = "See [["
        let draft = try XCTUnwrap(WikiLinks.draft(in: text, cursor: text.utf16.count))
        XCTAssertEqual(draft.query, "")
    }

    func testAFinishedLinkIsNotBeingTyped() {
        let text = "See [[Endurance]] today"
        XCTAssertNil(WikiLinks.draft(in: text, cursor: (text as NSString).length))
    }

    func testBracketsOnAnEarlierLineAreLeftBehind() {
        let text = "[[ was a false start\nand this is the next line"
        XCTAssertNil(WikiLinks.draft(in: text, cursor: (text as NSString).length))
    }

    func testPlainTextIsNotALink() {
        XCTAssertNil(WikiLinks.draft(in: "nothing to see", cursor: 5))
    }

    // MARK: What is offered

    func testTitlesThatStartWithWhatWasTypedComeFirst() {
        let titles = ["Weekend plan", "Endurance", "Ends of the week", "Health"]
        XCTAssertEqual(WikiLinks.suggestions(for: "en", among: titles),
                       ["Endurance", "Ends of the week", "Weekend plan"])
    }

    func testAnEmptyQueryOffersTheFirstFew() {
        let titles = (1...20).map { "Note \($0)" }
        XCTAssertEqual(WikiLinks.suggestions(for: "", among: titles).count, 8)
    }

    func testTheQueryIgnoresCaseAndSurroundingSpace() {
        XCTAssertEqual(WikiLinks.suggestions(for: " hEA ", among: ["Health", "Wealth"]), ["Health"])
    }

    // MARK: Choosing one

    func testChoosingATitleFinishesTheLink() {
        let text = "See [[Endu"
        let draft = WikiLinks.draft(in: text, cursor: (text as NSString).length)!

        let done = WikiLinks.completing(text, draft: draft, with: "Endurance")

        XCTAssertEqual(done.text, "See [[Endurance]]")
        XCTAssertEqual(done.cursor, (done.text as NSString).length)
    }

    func testClosingBracketsAreNotDoubled() {
        let text = "See [[Endu]] today"
        let draft = WikiLinks.draft(in: text, cursor: 10)!

        let done = WikiLinks.completing(text, draft: draft, with: "Endurance")

        XCTAssertEqual(done.text, "See [[Endurance]] today")
    }

    // MARK: Clicking one

    func testTheLinkUnderTheCursorIsFound() {
        let text = "Ask [[Anna]] about [[Race nutrition]]."
        XCTAssertEqual(WikiLinks.link(at: 8, in: text), "Anna")
        XCTAssertEqual(WikiLinks.link(at: 25, in: text), "Race nutrition")
        XCTAssertNil(WikiLinks.link(at: 2, in: text))
    }

    func testAnAliasAndAHeadingStillPointAtTheNote() {
        let text = "See [[Endurance|the plan]] and [[Health#Sleep]]."
        XCTAssertEqual(WikiLinks.titles(in: text), ["Endurance", "Health"])
        XCTAssertEqual(WikiLinks.link(at: 8, in: text), "Endurance")
        XCTAssertEqual(WikiLinks.link(at: 35, in: text), "Health")
    }

    func testALinkWithNothingBeforeTheBarNamesNoNote() {
        XCTAssertEqual(WikiLinks.titles(in: "[[|just words]] and [[#heading]]"), [])
    }

    func testEveryLinkInANoteIsListedOnce() {
        let text = "[[Endurance]] and [[endurance]] and [[Health]]"
        XCTAssertEqual(WikiLinks.titles(in: text), ["Endurance", "Health"])
    }
}

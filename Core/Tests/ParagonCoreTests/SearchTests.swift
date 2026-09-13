import XCTest
@testable import ParagonCore

final class SearchQueryTests: XCTestCase {
    func testParsesTermsFiltersAndPhrases() {
        let q = SearchQuery.parse("website \"contact form\" type:project status:active tag:web #marketing area:Business due:week is:open in:Projects")
        XCTAssertEqual(q.terms, ["website", "contact form"])
        XCTAssertEqual(q.kinds, [.project])
        XCTAssertEqual(q.statuses, ["active"])
        XCTAssertEqual(q.tags, ["web", "marketing"])
        XCTAssertEqual(q.area, "Business")
        XCTAssertEqual(q.dues, [.week])
        XCTAssertEqual(q.taskStates, [.open])
        XCTAssertEqual(q.pathPrefix, "Projects")
        XCTAssertTrue(q.wantsTasks)
    }

    func testUnknownFilterValuesStayTerms() {
        let q = SearchQuery.parse("type:banana due:someday 10:30 meeting")
        XCTAssertEqual(q.terms, ["type:banana", "due:someday", "10:30", "meeting"])
        XCTAssertTrue(q.kinds.isEmpty)
        XCTAssertTrue(q.dues.isEmpty)
        XCTAssertTrue(SearchQuery.parse("   ").isEmpty)
        XCTAssertEqual(SearchQuery.parse("type:projects kind:weekly").kinds, [.project, .daily])
    }

    // MARK: Ticking two boxes in a row (build 157)

    func testTwoBoxesInOneRowAreBothKept() {
        let q = SearchQuery.parse("is:open is:done due:today due:overdue")
        XCTAssertEqual(q.taskStates, [.open, .done])
        XCTAssertEqual(q.dues, [.today, .overdue])
        XCTAssertTrue(q.wantsTasks)
    }

    // MARK: What the query says it is

    func testTheWordDoneIsAWordAndNotTheDoneBox() {
        // The whole reason for build 157: these two look alike and ask different questions.
        let word = SearchQuery.parse("done")
        XCTAssertEqual(word.terms, ["done"])
        XCTAssertTrue(word.taskStates.isEmpty)
        XCTAssertFalse(word.wantsTasks)
        XCTAssertEqual(word.summary, "Notes with the word \u{201C}done\u{201D}.")

        let box = SearchQuery.parse("is:done")
        XCTAssertTrue(box.terms.isEmpty)
        XCTAssertEqual(box.taskStates, [.done])
        XCTAssertEqual(box.summary, "Tasks that are done.")
    }

    func testTheSummaryNamesEveryPartOfTheQuery() {
        let q = SearchQuery.parse("plan type:project status:active #travel due:week is:open")
        XCTAssertEqual(q.summary,
                       "Tasks that are not done, due this week, in Projects, marked active, tagged #travel, with the word \u{201C}plan\u{201D}.")
    }

    func testAnEmptyQuerySaysSo() {
        XCTAssertEqual(SearchQuery.parse("").summary, "Nothing searched for yet. Write a word, or tick a box.")
    }

    func testTheSummaryJoinsWithAnd() {
        XCTAssertEqual(SearchQuery.list(["a"]), "a")
        XCTAssertEqual(SearchQuery.list(["a", "b"]), "a and b")
        XCTAssertEqual(SearchQuery.list(["a", "b", "c"]), "a, b and c")
    }
}

final class SearchTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 9, day: 5)
    var index: NoteIndex!

    override func setUp() {
        let notes = [
            Note(relativePath: "Inbox.md", kind: .inbox, text: "# Inbox\n\n## Tasks\n\n- [ ] Book dentist >2026-09-15\n- [ ] Read the PARA method !!\n"),
            Note(relativePath: "Projects/Website relaunch.md", kind: .project, text: """
            ---
            title: Website relaunch
            type: project
            status: active
            area: Business
            tags: [web, marketing]
            ---
            # Website relaunch

            The new site needs a contact form and analytics.

            ## Tasks

            - [ ] Collect the copy for the services page !!
            - [ ] Get two quotes from web designers >2026-09-01
            - [x] Export the old page texts @done(2026-09-04 16:20)
            """),
            Note(relativePath: "Projects/Garden shed.md", kind: .project, text: "---\ntitle: Garden shed\nstatus: on-hold\narea: Home\n---\n# Garden shed\n\n- [ ] Order timber >2026-09-05\n"),
            Note(relativePath: "Resources/Brand guide.md", kind: .resource, text: "---\ntitle: Brand guide\ntags: [marketing]\n---\n# Brand guide\n\nTone of voice for the website and print.\n"),
            Note(relativePath: "Archive/Projects/Old site.md", kind: .archive, text: "---\ntitle: Old site\nstatus: archived\n---\n# Old site\n\nThe old website archive.\n"),
        ]
        index = NoteIndex(notes: notes)
    }

    func testTextSearchRanksTitleMatchesFirstAndReturnsSnippets() {
        let hits = index.search(text: "website", today: today)
        XCTAssertEqual(hits.map(\.note.title), ["Website relaunch", "Brand guide", "Old site"])
        XCTAssertEqual(hits[1].snippets, ["Tone of voice for the website and print."])
        XCTAssertTrue(hits[0].snippets.isEmpty || hits[0].snippets.allSatisfy { !$0.hasPrefix("#") })
    }

    func testAllTermsMustMatchAndPhrasesAreExact() {
        XCTAssertEqual(index.search(text: "website contact", today: today).map(\.note.title), ["Website relaunch"])
        XCTAssertEqual(index.search(text: "\"contact form\"", today: today).map(\.note.title), ["Website relaunch"])
        XCTAssertTrue(index.search(text: "\"form contact\"", today: today).isEmpty)
        XCTAssertTrue(index.search(text: "", today: today).isEmpty)
    }

    func testFilters() {
        XCTAssertEqual(index.search(text: "type:project", today: today).map(\.note.title), ["Garden shed", "Website relaunch"])
        XCTAssertEqual(index.search(text: "type:project status:active", today: today).map(\.note.title), ["Website relaunch"])
        XCTAssertEqual(index.search(text: "status:on-hold", today: today).map(\.note.title), ["Garden shed"])
        XCTAssertEqual(index.search(text: "status:archived", today: today).map(\.note.title), ["Old site"])
        XCTAssertEqual(index.search(text: "#marketing", today: today).map(\.note.title), ["Brand guide", "Website relaunch"])
        XCTAssertEqual(index.search(text: "tag:web tag:marketing", today: today).map(\.note.title), ["Website relaunch"])
        XCTAssertEqual(index.search(text: "area:business", today: today).map(\.note.title), ["Website relaunch"])
        XCTAssertEqual(index.search(text: "in:Resources", today: today).map(\.note.title), ["Brand guide"])
    }

    func testTaskFilters() {
        let overdue = index.searchTasks(SearchQuery.parse("due:overdue"), today: today)
        XCTAssertEqual(overdue.map(\.task.title), ["Get two quotes from web designers"])
        let dueToday = index.searchTasks(SearchQuery.parse("due:today is:open"), today: today)
        XCTAssertEqual(dueToday.map(\.task.title), ["Order timber"])
        let week = index.searchTasks(SearchQuery.parse("due:week"), today: today)
        XCTAssertEqual(Set(week.map(\.task.title)), ["Get two quotes from web designers", "Order timber"])
        let done = index.searchTasks(SearchQuery.parse("is:done"), today: today)
        XCTAssertEqual(done.map(\.task.title), ["Export the old page texts"])
        let undated = index.searchTasks(SearchQuery.parse("due:none is:open type:inbox"), today: today)
        XCTAssertEqual(undated.map(\.task.title), ["Read the PARA method"])
        let termAndTask = index.searchTasks(SearchQuery.parse("copy is:open"), today: today)
        XCTAssertEqual(termAndTask.map(\.task.title), ["Collect the copy for the services page"])
        XCTAssertTrue(index.search(text: "nothing-here is:open", today: today).isEmpty)
    }

    func testTextMatchesInsideTasksAreListedOnTheHit() {
        let hit = index.search(text: "designers", today: today).first
        XCTAssertEqual(hit?.note.title, "Website relaunch")
        XCTAssertEqual(hit?.tasks.map(\.title), ["Get two quotes from web designers"])
    }
}

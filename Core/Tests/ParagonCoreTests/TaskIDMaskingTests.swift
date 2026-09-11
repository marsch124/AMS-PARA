import XCTest
@testable import ParagonCore

final class TaskIDMaskingTests: XCTestCase {
    private let original = """
    ## Tasks

    - [ ] Buy milk ^tabc123
    - [ ] Call the bank >2026-09-10 ^tdef456
        - [ ] Ask about fees ^t111111
    - [x] Old thing @done(2026-09-01 10:00) ^t222222
    """

    func testMarkersAreHiddenAndNothingElseChanges() {
        let shown = TaskIDMasking.hidden(in: original)
        XCTAssertFalse(shown.contains("^t"))
        XCTAssertEqual(shown, """
        ## Tasks

        - [ ] Buy milk
        - [ ] Call the bank >2026-09-10
            - [ ] Ask about fees
        - [x] Old thing @done(2026-09-01 10:00)
        """)
        XCTAssertEqual(TaskIDMasking.hidden(in: "# Note\n\nNo tasks here."), "# Note\n\nNo tasks here.")
    }

    func testUntouchedTextRoundTrips() {
        let shown = TaskIDMasking.hidden(in: original)
        XCTAssertEqual(TaskIDMasking.restored(shown, from: original), original)
    }

    func testEditingATitleKeepsItsMarker() {
        var shown = TaskIDMasking.hidden(in: original)
        shown = shown.replacingOccurrences(of: "- [ ] Call the bank >2026-09-10",
                                           with: "- [ ] Call the bank about the mortgage >2026-09-11")
        let restored = TaskIDMasking.restored(shown, from: original)
        XCTAssertTrue(restored.contains("- [ ] Call the bank about the mortgage >2026-09-11 ^tdef456"), restored)
        XCTAssertTrue(restored.contains("- [ ] Buy milk ^tabc123"))
        XCTAssertTrue(restored.contains("    - [ ] Ask about fees ^t111111"))
    }

    func testTickingATaskInTheTextKeepsItsMarker() {
        let shown = TaskIDMasking.hidden(in: original).replacingOccurrences(of: "- [ ] Buy milk", with: "- [x] Buy milk")
        XCTAssertTrue(TaskIDMasking.restored(shown, from: original).contains("- [x] Buy milk ^tabc123"))
    }

    func testANewTaskGetsNoMarkerAndTheOthersKeepTheirs() {
        let shown = TaskIDMasking.hidden(in: original)
            .replacingOccurrences(of: "- [ ] Buy milk", with: "- [ ] Buy milk\n- [ ] Buy bread")
        let restored = TaskIDMasking.restored(shown, from: original)
        XCTAssertTrue(restored.contains("- [ ] Buy milk ^tabc123"), restored)
        XCTAssertTrue(restored.contains("- [ ] Buy bread\n"), restored)
        XCTAssertFalse(restored.contains("- [ ] Buy bread ^"), restored)
        XCTAssertTrue(restored.contains("- [ ] Call the bank >2026-09-10 ^tdef456"))
    }

    func testADeletedTaskTakesItsMarkerWithIt() {
        let shown = TaskIDMasking.hidden(in: original).replacingOccurrences(of: "- [ ] Buy milk\n", with: "")
        let restored = TaskIDMasking.restored(shown, from: original)
        XCTAssertFalse(restored.contains("tabc123"), restored)
        XCTAssertTrue(restored.contains("- [ ] Call the bank >2026-09-10 ^tdef456"))
        XCTAssertTrue(restored.contains("    - [ ] Ask about fees ^t111111"))
    }

    func testTypingPlainTextIsUnaffected() {
        let shown = TaskIDMasking.hidden(in: original) + "\n\nA note to self."
        let restored = TaskIDMasking.restored(shown, from: original)
        XCTAssertTrue(restored.hasSuffix("A note to self."))
        XCTAssertTrue(restored.contains("^tabc123"))
    }
}

import XCTest
@testable import AMSParaCore

final class CaptureTests: XCTestCase {
    var vault: Vault!
    let today = DateOnly(year: 2026, month: 9, day: 5)

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testCaptureTaskIntoInbox() throws {
        let note = try vault.capture(CaptureItem(text: "Call the bank >2026-09-10 !!"))
        XCTAssertEqual(note.relativePath, "Inbox.md")
        let task = try XCTUnwrap(note.tasks.last)
        XCTAssertEqual(task.title, "Call the bank")
        XCTAssertEqual(task.dueDate, DateOnly(year: 2026, month: 9, day: 10))
        XCTAssertEqual(task.priority, 2)
        XCTAssertEqual(try vault.loadNote(relativePath: "Inbox.md").tasks.count, 1)
    }

    func testCaptureWithLinkAppendsMarkdownLink() throws {
        let item = CaptureItem(text: "Read later", url: URL(string: "https://example.com/article")!)
        XCTAssertEqual(item.lineText, "Read later [example.com](https://example.com/article)")
        let note = try vault.capture(item)
        XCTAssertEqual(note.tasks.last?.title, "Read later [example.com](https://example.com/article)")

        let linkOnly = CaptureItem(text: "", url: URL(string: "https://example.com")!)
        XCTAssertEqual(linkOnly.lineText, "[example.com](https://example.com)")
    }

    func testCaptureIntoTodayAndProjectAndAsNote() throws {
        let project = try vault.createNote(kind: .project, title: "Shed")
        XCTAssertFalse(vault.dailyNoteExists(for: today))

        let daily = try vault.capture(CaptureItem(text: "Water plants", target: .today), today: today)
        XCTAssertEqual(daily.relativePath, "Calendar/20260905.md")
        XCTAssertEqual(daily.tasks.map(\.title), ["Water plants"])

        let proj = try vault.capture(CaptureItem(text: "Order timber", target: .note(path: project.relativePath)))
        XCTAssertEqual(proj.tasks.map(\.title).last, "Order timber")

        let asNote = try vault.capture(CaptureItem(text: "Idea: paint it green", target: .note(path: project.relativePath), asTask: false))
        XCTAssertTrue(asNote.body.contains("## Notes\n- Idea: paint it green\n\n## Log"), asNote.body)
        XCTAssertEqual(asNote.tasks.count, proj.tasks.count)

        // Unknown target falls back to the Inbox.
        let fallback = try vault.capture(CaptureItem(text: "Lost", target: .note(path: "Projects/Nope.md")))
        XCTAssertEqual(fallback.relativePath, "Inbox.md")
    }

    func testUrlSchemeRoundTrip() throws {
        let url = try XCTUnwrap(URL(string: "amspara://capture?text=Buy%20milk%20%3E2026-09-10&target=today&url=https%3A%2F%2Fexample.com&note=1"))
        let item = try XCTUnwrap(CaptureItem(url: url))
        XCTAssertEqual(item.text, "Buy milk >2026-09-10")
        XCTAssertEqual(item.target, .today)
        XCTAssertEqual(item.url?.absoluteString, "https://example.com")
        XCTAssertFalse(item.asTask)

        let back = try XCTUnwrap(item.captureURL)
        XCTAssertEqual(CaptureItem(url: back)?.text, item.text)
        XCTAssertEqual(CaptureItem(url: back)?.target, .today)

        XCTAssertNil(CaptureItem(url: URL(string: "amspara://capture")!))
        XCTAssertNil(CaptureItem(url: URL(string: "https://example.com/capture?text=x")!))
        XCTAssertEqual(CaptureItem(url: URL(string: "amspara://capture?text=x&target=Projects%2FShed.md")!)?.target, .note(path: "Projects/Shed.md"))
        XCTAssertEqual(CaptureItem(url: URL(string: "amspara://capture?text=x")!)?.target, .inbox)
    }

    func testOutboxAppendPeekDrain() throws {
        let outbox = CaptureOutbox(fileURL: vault.rootURL.appendingPathComponent(".ams-para/outbox.jsonl"))
        XCTAssertTrue(outbox.peek().isEmpty)
        let first = CaptureItem(text: "First", createdAt: Date(timeIntervalSince1970: 1_000))
        let second = CaptureItem(text: "Second", url: URL(string: "https://example.com"), target: .today, asTask: false, createdAt: Date(timeIntervalSince1970: 2_000))
        try outbox.append(second)
        try outbox.append(first)
        XCTAssertEqual(outbox.peek().map(\.text), ["First", "Second"])
        let drained = outbox.drain()
        XCTAssertEqual(drained, [first, second])
        XCTAssertTrue(outbox.peek().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outbox.fileURL.path))

        for item in drained { try vault.capture(item, today: today) }
        XCTAssertEqual(try vault.loadNote(relativePath: "Inbox.md").tasks.map(\.title), ["First"])
        XCTAssertTrue(try vault.dailyNote(for: today).body.contains("- Second [example.com](https://example.com)"))
    }

    func testAppendLineCreatesSectionWhenMissing() {
        var note = Note(relativePath: "Inbox.md", kind: .inbox, text: "# Inbox\n")
        let index = note.appendLine("- a thought", under: "Notes")
        XCTAssertEqual(note.body, "# Inbox\n\n## Notes\n- a thought\n")
        XCTAssertEqual(index, 3)
    }

    func testCaptureToAPathOutsideTheVaultLandsInTheInbox() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let outside = vault.rootURL.deletingLastPathComponent().appendingPathComponent("outside-\(UUID().uuidString).md")
        try "# Outside\n".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }
        let item = CaptureItem(url: URL(string: "amspara://capture?text=hi&target=../\(outside.lastPathComponent)")!)!
        let note = try vault.capture(item)
        XCTAssertEqual(note.relativePath, "Inbox.md")
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "# Outside\n")
        let config = CaptureItem(url: URL(string: "amspara://capture?text=hi&target=.ams-para/config.json")!)!
        XCTAssertEqual(try vault.capture(config).relativePath, "Inbox.md")
    }

    func testOnlyWebAndMailLinksAreKept() {
        XCTAssertNil(CaptureItem(url: URL(string: "amspara://capture?text=x&url=file:///etc/passwd")!)?.url)
        XCTAssertNil(CaptureItem(url: URL(string: "amspara://capture?text=x&url=javascript:alert(1)")!)?.url)
        XCTAssertEqual(CaptureItem(url: URL(string: "amspara://capture?text=x&url=https://example.com")!)?.url?.host, "example.com")
    }

    func testDrainKeepsItemsAppendedMeanwhile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = CaptureOutbox(fileURL: dir.appendingPathComponent("capture-outbox.jsonl"))
        try outbox.append(CaptureItem(text: "one"))
        let drained = outbox.drain()
        try outbox.append(CaptureItem(text: "two"))
        XCTAssertEqual(drained.map(\.text), ["one"])
        XCTAssertEqual(outbox.peek().map(\.text), ["two"])
        outbox.requeue(drained)
        XCTAssertEqual(Set(outbox.peek().map(\.text)), ["one", "two"])
    }
}

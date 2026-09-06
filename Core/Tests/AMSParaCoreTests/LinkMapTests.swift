import XCTest
@testable import AMSParaCore

final class LinkMapTests: XCTestCase {
    private func note(_ path: String, kind: ParaKind, _ frontmatter: [(String, String)] = [],
                      related: [String] = [], body: String = "") -> Note {
        var fm = Frontmatter()
        fm.set("title", String(path.split(separator: "/").last!.dropLast(3)))
        fm.set("type", kind.frontmatterType)
        for (key, value) in frontmatter { fm.set(key, value) }
        if !related.isEmpty { fm.set("related", list: related) }
        return Note(relativePath: path, kind: kind, frontmatter: fm, body: body)
    }

    private var sample: [Note] {
        [
            note("Goals/Stay fit.md", kind: .goal, [("horizon", "life")]),
            note("Goals/Walk the Kungsleden.md", kind: .goal, [("horizon", "year"), ("goal", "Stay fit")]),
            note("Areas/Health.md", kind: .area, [("goal", "Stay fit")], body: "- [ ] Yearly check-up >2026-11-03\n"),
            note("Areas/Business.md", kind: .area),
            note("Projects/Run a 10k.md", kind: .project, [("area", "Health"), ("goal", "Walk the Kungsleden")],
                 body: "## Tasks\n- [ ] Register !!!\n    - [ ] Pay the fee\n- [ ] Buy shoes\n- [x] Done @done(2026-09-01 10:00)\n"),
            note("Projects/Website relaunch.md", kind: .project, [("area", "Business")], related: ["Brand guide"], body: "- [ ] Collect copy\n"),
            note("Projects/Loose end.md", kind: .project, body: "- [ ] Something\n"),
            note("Projects/Old.md", kind: .project, [("status", "done"), ("goal", "Stay fit")]),
            note("Resources/Training plan.md", kind: .resource, related: ["Run a 10k", "Health"]),
            note("Resources/Brand guide.md", kind: .resource),
            note("Resources/PARA method.md", kind: .resource),
            note("Archive/Old website.md", kind: .archive, [("area", "Business")]),
            note("Calendar/20260905.md", kind: .daily, body: "- [ ] Daily thing\n"),
            note("Inbox.md", kind: .inbox, body: "- [ ] Unfiled\n"),
        ]
    }

    func testTreeFollowsGoalsAreasProjectsAndTasks() {
        let map = NoteIndex(notes: sample).linkMap()

        XCTAssertEqual(map.roots.map(\.id), ["Goals/Stay fit.md", "Inbox.md", "group:unlinked", "group:resources", "group:archive"])

        let stayFit = map.roots[0]
        XCTAssertEqual(stayFit.children.map(\.id), ["Goals/Walk the Kungsleden.md", "Areas/Health.md"])

        let health = stayFit.children[1]
        XCTAssertEqual(health.children.map(\.id), ["Projects/Run a 10k.md", "Areas/Health.md#0"])

        let run = health.children[0]
        XCTAssertEqual(run.children.map(\.title), ["Register", "Buy shoes", "Training plan"], "subtasks and done tasks stay out; the resource stacks last")
        XCTAssertTrue(run.children.allSatisfy(\.isChip))

        XCTAssertEqual(map.parent(of: "Projects/Run a 10k.md"), "Areas/Health.md")
        XCTAssertTrue(map.links.contains(MapLink(from: "Projects/Run a 10k.md", to: "Goals/Walk the Kungsleden.md")),
                      "a project under its area keeps a second link to its goal")
        XCTAssertNil(map.node("Calendar/20260905.md"), "calendar notes stay out")
    }

    func testResourcesSitUnderWhatTheySupport() {
        let map = NoteIndex(notes: sample).linkMap()
        XCTAssertEqual(map.parent(of: "Resources/Training plan.md"), "Projects/Run a 10k.md", "the project comes first")
        XCTAssertTrue(map.links.contains(MapLink(from: "Resources/Training plan.md", to: "Areas/Health.md")), "the area gets the second link")
        XCTAssertEqual(map.parent(of: "Resources/Brand guide.md"), "Projects/Website relaunch.md", "linked from the project's related list")
        XCTAssertEqual(map.parent(of: "Resources/PARA method.md"), "group:resources")
    }

    func testUnlinkedAndArchivedNotesAreGrouped() {
        let map = NoteIndex(notes: sample).linkMap()
        let unlinked = map.node("group:unlinked")!
        XCTAssertEqual(unlinked.children.map(\.id), ["Areas/Business.md", "Projects/Loose end.md"])
        XCTAssertEqual(map.parent(of: "Projects/Website relaunch.md"), "Areas/Business.md")

        let archive = map.node("group:archive")!
        XCTAssertEqual(Set(archive.children.map(\.id)), ["Projects/Old.md", "Archive/Old website.md"], "done projects park with the archive")
        XCTAssertTrue(map.links.contains(MapLink(from: "Projects/Old.md", to: "Goals/Stay fit.md")))
        XCTAssertTrue(map.links.contains(MapLink(from: "Archive/Old website.md", to: "Areas/Business.md")))
    }

    func testUpstreamAndDownstreamFollowTreeAndLinks() {
        let map = NoteIndex(notes: sample).linkMap()
        let up = map.upstream(of: "Projects/Run a 10k.md")
        XCTAssertEqual(up, ["Areas/Health.md", "Goals/Stay fit.md", "Goals/Walk the Kungsleden.md"])

        let down = map.downstream(of: "Goals/Stay fit.md")
        XCTAssertTrue(down.contains("Projects/Run a 10k.md"))
        XCTAssertTrue(down.contains("Projects/Run a 10k.md#1"), "the project's tasks serve the goal too")
        XCTAssertTrue(down.contains("Resources/Training plan.md"))
        XCTAssertTrue(down.contains("Projects/Old.md"), "linked, not just tree children")
        XCTAssertFalse(down.contains("Areas/Business.md"))

        XCTAssertEqual(map.upstream(of: "Projects/Loose end.md"), [], "groups are not served")
    }

    func testTaskOverflowFoldsIntoMoreChip() {
        let body = (1...10).map { "- [ ] Task \($0)" }.joined(separator: "\n")
        let project = note("Projects/Busy.md", kind: .project, body: body)
        let map = NoteIndex(notes: [project]).linkMap(taskLimit: 3)
        let busy = map.node("group:unlinked")!.children[0]
        XCTAssertEqual(busy.children.count, 4)
        XCTAssertEqual(busy.children.last?.title, "+7 more")
        XCTAssertEqual(busy.children.last?.notePath, "Projects/Busy.md")
    }

    func testGoalLoopDoesNotHang() {
        let a = note("Goals/A.md", kind: .goal, [("goal", "B")])
        let b = note("Goals/B.md", kind: .goal, [("goal", "A")])
        let map = NoteIndex(notes: [a, b]).linkMap()
        XCTAssertEqual(map.roots.count, 1)
        XCTAssertEqual(map.allNodes.count, 2)
    }

    func testGoalMatchingIsForgiving() {
        let index = NoteIndex(notes: sample)
        XCTAssertEqual(index.goal(matching: "stay fit")?.relativePath, "Goals/Stay fit.md")
        XCTAssertEqual(index.goal(matching: "Kungsleden")?.relativePath, "Goals/Walk the Kungsleden.md")
        XCTAssertNil(index.goal(matching: "Nothing like it"))
    }
}

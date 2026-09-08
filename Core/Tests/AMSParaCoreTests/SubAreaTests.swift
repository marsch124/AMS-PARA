import XCTest
@testable import AMSParaCore

final class SubAreaTests: XCTestCase {
    private func area(_ title: String, parent: String? = nil, order: Int? = nil) -> Note {
        var fm = Frontmatter()
        fm.set("title", title)
        fm.set("type", ParaKind.area.frontmatterType)
        if let parent { fm.set("parent", parent) }
        if let order { fm.set("order", "\(order)") }
        return Note(relativePath: "Areas/\(title).md", kind: .area, frontmatter: fm, body: "")
    }

    func testParentIsReadFromFrontmatterForAreasOnly() {
        XCTAssertEqual(area("Yoga", parent: "Mobility").parent, "Mobility")
        XCTAssertNil(area("Mobility").parent)

        var fm = Frontmatter()
        fm.set("title", "A project")
        fm.set("type", ParaKind.project.frontmatterType)
        fm.set("parent", "Mobility")
        XCTAssertNil(Note(relativePath: "Projects/A project.md", kind: .project, frontmatter: fm, body: "").parent)
    }

    func testTreeGroupsSubAreasUnderTheirParent() {
        let index = NoteIndex(notes: [
            area("Mobility", order: 10), area("Stretching", parent: "Mobility", order: 20),
            area("Yoga", parent: "Mobility", order: 10), area("Admin", order: 20),
        ])
        let tree = index.areaTree()

        XCTAssertEqual(tree.map(\.area.title), ["Mobility", "Admin"])
        XCTAssertEqual(tree[0].subAreas.map(\.title), ["Yoga", "Stretching"])
        XCTAssertEqual(index.areasInFamilyOrder().map(\.title), ["Mobility", "Yoga", "Stretching", "Admin"])
        XCTAssertEqual(index.parentArea(of: area("Yoga", parent: "Mobility"))?.title, "Mobility")
    }

    func testNestingStopsAtOneLevel() {
        let index = NoteIndex(notes: [
            area("Mobility"), area("Yoga", parent: "Mobility"), area("Breathing", parent: "Yoga"),
        ])

        XCTAssertNil(index.parentArea(of: index.note(matching: "Breathing")!))
        XCTAssertEqual(index.areaTree().map(\.area.title), ["Breathing", "Mobility"])
        XCTAssertEqual(index.subAreas(of: index.note(matching: "Yoga")!), [])
    }

    func testAreasPointingAtEachOtherBothStayInTheList() {
        let index = NoteIndex(notes: [area("A", parent: "B"), area("B", parent: "A")])

        XCTAssertEqual(index.areaTree().map(\.area.title), ["A", "B"])
    }

    func testAnAreaIsNotItsOwnParent() {
        let index = NoteIndex(notes: [area("Mobility", parent: "Mobility")])

        XCTAssertNil(index.parentArea(of: index.note(matching: "Mobility")!))
    }
}

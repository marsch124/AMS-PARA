import Foundation

/// How far out a goal reaches.
public enum GoalHorizon: String, CaseIterable, Codable, Sendable {
    case life
    case long
    case year

    public var label: String {
        switch self {
        case .life: return "Life goal"
        case .long: return "Long term"
        case .year: return "This year"
        }
    }
}

/// A markdown note: optional YAML frontmatter followed by a body.
public struct Note: Equatable, Identifiable, Sendable {
    /// Path relative to the vault root, e.g. `Projects/Website relaunch.md`.
    public var relativePath: String
    public var kind: ParaKind
    public var frontmatter: Frontmatter
    public var body: String
    public var modifiedAt: Date?

    public var id: String { relativePath }

    public init(relativePath: String, kind: ParaKind, frontmatter: Frontmatter = Frontmatter(), body: String = "", modifiedAt: Date? = nil) {
        self.relativePath = relativePath
        self.kind = kind
        self.frontmatter = frontmatter
        self.body = body
        self.modifiedAt = modifiedAt
    }

    public init(relativePath: String, kind: ParaKind, text: String, modifiedAt: Date? = nil) {
        let parsed = Frontmatter.parse(text)
        self.init(relativePath: relativePath, kind: kind, frontmatter: parsed.frontmatter, body: parsed.body, modifiedAt: modifiedAt)
    }

    /// Full file contents.
    public var text: String {
        get { frontmatter.serialized() + body }
        set {
            let parsed = Frontmatter.parse(newValue)
            frontmatter = parsed.frontmatter
            body = parsed.body
        }
    }

    public var fileName: String {
        let last = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        return last.hasSuffix(".md") ? String(last.dropLast(3)) : last
    }

    public var title: String { frontmatter.string("title") ?? fileName }
    public var status: String? { frontmatter.string("status")?.lowercased() }
    public var tags: [String] { frontmatter.list("tags") }
    public var related: [String] { frontmatter.list("related") }
    public var area: String? { frontmatter.string("area") }
    /// The goal this note serves (projects, areas, or a dated goal pointing at a life goal).
    /// Written as `goal: Title`; a value typed inside `[...]` is joined back into one title.
    public var goal: String? {
        let parts = frontmatter.list("goal").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: Goal notes

    /// `life` for enduring direction without a date, `long` for 3 to 10 years, `year` for 1 to 2 years.
    public var horizon: GoalHorizon? {
        guard kind == .goal else { return nil }
        return frontmatter.string("horizon").flatMap { GoalHorizon(rawValue: $0.lowercased()) } ?? .year
    }
    public var targetDate: DateOnly? { frontmatter.string("target").flatMap(DateOnly.init) }
    public var measure: String? { frontmatter.string("measure") }
    public var isAchieved: Bool { status == "achieved" || status == "done" }
    public var dueDate: DateOnly? { frontmatter.string("due").flatMap(DateOnly.init) }

    /// `sync: false` in the frontmatter keeps a note out of Reminders.
    public var isSyncEnabled: Bool { frontmatter.bool("sync") ?? true }

    /// The Reminders list that mirrors this note (frontmatter `reminders-list`, else the title).
    public var remindersListName: String { frontmatter.string("reminders-list") ?? title }

    public var isArchived: Bool { kind == .archive || status == "archived" }

    /// Date of the last review (frontmatter `reviewed: YYYY-MM-DD`).
    public var reviewedDate: DateOnly? { frontmatter.string("reviewed").flatMap(DateOnly.init) }

    // MARK: Daily notes

    /// The date of a daily note, parsed from its `YYYYMMDD` file name.
    public var dailyDate: DateOnly? {
        guard kind == .daily else { return nil }
        return Self.dailyDate(fromFileName: fileName)
    }

    /// The week of a weekly note, parsed from its `YYYY-Www` file name.
    public var weekRef: WeekRef? {
        guard kind == .daily else { return nil }
        return WeekRef(fileName)
    }

    public var isWeeklyNote: Bool { weekRef != nil }

    /// Title for lists: calendar notes show their date or week, everything else its title.
    public var displayTitle: String {
        if let dailyDate { return Self.dailyTitle(for: dailyDate) }
        if let weekRef { return weekRef.title }
        return title
    }

    public static func dailyFileName(for date: DateOnly) -> String {
        String(format: "%04d%02d%02d", date.year, date.month, date.day)
    }

    public static func dailyDate(fromFileName name: String) -> DateOnly? {
        guard name.count == 8, name.allSatisfy(\.isNumber),
              let y = Int(name.prefix(4)), let m = Int(name.dropFirst(4).prefix(2)), let d = Int(name.suffix(2)) else { return nil }
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }
        return DateOnly(year: y, month: m, day: d)
    }

    private static let dailyTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return f
    }()

    public static func dailyTitle(for date: DateOnly) -> String {
        guard let d = date.date() else { return date.description }
        return dailyTitleFormatter.string(from: d)
    }

    // MARK: Tasks

    public var tasks: [TaskItem] { TaskParser.parse(text: body) }

    public var openTasks: [TaskItem] { tasks.filter { !$0.isDone } }

    public var lines: [String] {
        get { body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
        set { body = newValue.joined(separator: "\n") }
    }

    /// Rewrites the line the task came from. The line must still hold the same task (same id,
    /// or the same title when it has no id); if lines moved, the task is found by its id or,
    /// for a task getting its first id, by its title. `previousID` names the id the line
    /// carried before, for the case where a task is given a fresh id.
    /// Returns false when the task is no longer in the note.
    @discardableResult
    public mutating func replace(task: TaskItem, previousID: String? = nil) -> Bool {
        var current = lines
        let wantedID = previousID ?? task.id
        func matches(_ line: String) -> Bool {
            guard let existing = TaskParser.parse(line: line) else { return false }
            if let wantedID, let existingID = existing.id { return wantedID == existingID }
            return existing.title == task.title
        }
        var index = task.lineIndex
        if !(index >= 0 && index < current.count && matches(current[index])) {
            let byID = wantedID.flatMap { id in current.firstIndex { TaskParser.parse(line: $0)?.id == id } }
            let byTitle = current.firstIndex {
                guard let existing = TaskParser.parse(line: $0), existing.id == nil else { return false }
                return existing.title == task.title
            }
            guard let found = byID ?? (previousID == nil ? byTitle : nil) else { return false }
            index = found
        }
        let newLine = task.serialized
        guard current[index] != newLine else { return true }
        current[index] = newLine
        lines = current
        return true
    }

    /// Appends a task at the end of the `## Tasks` section (created if missing).
    /// Returns the task with its final `lineIndex`.
    @discardableResult
    public mutating func append(task: TaskItem, sectionHeading: String = "Tasks") -> TaskItem {
        var inserted = task
        inserted.lineIndex = appendLine(task.serialized, under: sectionHeading)
        return inserted
    }

    /// Appends a line at the end of a `## Heading` section (created at the end of the note if missing).
    /// Returns the index of the inserted line.
    @discardableResult
    public mutating func appendLine(_ line: String, under sectionHeading: String) -> Int {
        var current = lines
        let index: Int
        if let heading = current.firstIndex(where: { Self.isHeading($0, titled: sectionHeading) }) {
            let level = Self.headingLevel(current[heading])
            var end = heading + 1
            while end < current.count {
                let l = Self.headingLevel(current[end])
                if l > 0 && l <= level { break }
                end += 1
            }
            var insertAt = end
            while insertAt > heading + 1, current[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                insertAt -= 1
            }
            index = insertAt
            current.insert(line, at: insertAt)
        } else {
            while let last = current.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                current.removeLast()
            }
            if !current.isEmpty { current.append("") }
            current.append("## \(sectionHeading)")
            index = current.count
            current.append(line)
            current.append("")
        }
        lines = current
        return index
    }

    /// Parent tasks of a subtask, outermost first.
    public func parentChain(of task: TaskItem) -> [TaskItem] {
        let byLine = Dictionary(tasks.map { ($0.lineIndex, $0) }, uniquingKeysWith: { a, _ in a })
        var chain: [TaskItem] = []
        var cursor = task.parentLineIndex
        while let index = cursor, let parent = byLine[index], chain.count < 20 {
            chain.insert(parent, at: 0)
            cursor = parent.parentLineIndex
        }
        return chain
    }

    /// `Parent › Child` prefix used for the reminder title of a subtask, nil for top-level tasks.
    public func parentPrefix(for task: TaskItem) -> String? {
        let chain = parentChain(of: task)
        return chain.isEmpty ? nil : chain.map(\.title).joined(separator: Self.subtaskSeparator)
    }

    /// The title a subtask carries in Apple Reminders: its parents' titles, then its own.
    public func syncTitle(for task: TaskItem) -> String {
        guard let prefix = parentPrefix(for: task) else { return task.title }
        return prefix + Self.subtaskSeparator + task.title
    }

    public static let subtaskSeparator = " › "

    public func subtasks(of task: TaskItem) -> [TaskItem] {
        tasks.filter { $0.parentLineIndex == task.lineIndex }
    }

    /// Inserts a subtask after the parent's last descendant. Returns it with its final `lineIndex`.
    @discardableResult
    public mutating func appendSubtask(_ subtask: TaskItem, to parent: TaskItem) -> TaskItem {
        var current = lines
        let all = tasks
        var insertAt = parent.lineIndex + 1
        if let parentIndex = all.firstIndex(where: { $0.lineIndex == parent.lineIndex }) {
            var j = parentIndex + 1
            while j < all.count, all[j].indentLevel > parent.indentLevel {
                insertAt = all[j].lineIndex + 1
                j += 1
            }
        }
        var child = subtask
        child.indent = parent.indent + "    "
        child.bullet = parent.bullet
        child.lineIndex = insertAt
        child.parentLineIndex = parent.lineIndex
        current.insert(child.serialized, at: min(insertAt, current.count))
        lines = current
        return child
    }

    public mutating func removeTask(at lineIndex: Int) {
        var current = lines
        guard lineIndex >= 0, lineIndex < current.count else { return }
        current.remove(at: lineIndex)
        lines = current
    }

    // MARK: Links

    static let wikilinkRegex = try! NSRegularExpression(pattern: #"\[\[([^\]\|#]+)(?:#[^\]\|]*)?(?:\|[^\]]*)?\]\]"#)

    /// Targets of `[[Title]]`, `[[Title|alias]]` and `[[Title#heading]]` links in the body.
    public var wikilinks: [String] {
        let ns = body as NSString
        let matches = Self.wikilinkRegex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var out: [String] = []
        for m in matches {
            let target = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if seen.insert(target.lowercased()).inserted { out.append(target) }
        }
        return out
    }

    /// Everything this note points at: frontmatter `related`, `area`, `goal`, and wikilinks.
    public var outgoingReferences: [String] {
        var refs = related
        if let area { refs.append(area) }
        if let goal { refs.append(goal) }
        refs.append(contentsOf: wikilinks)
        return refs
    }

    // MARK: Helpers

    static func headingLevel(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 } else { break }
        }
        guard count > 0, count <= 6 else { return 0 }
        let after = line.dropFirst(count)
        return after.first == " " || after.isEmpty ? count : 0
    }

    static func isHeading(_ line: String, titled title: String) -> Bool {
        let level = headingLevel(line)
        guard level > 0 else { return false }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return text.caseInsensitiveCompare(title) == .orderedSame
    }
}

import Foundation

/// One task line in a markdown note, NotePlan style:
/// `- [ ] Call the bank #finance !! >2026-09-10T14:30 @done(2026-09-05 10:00) ^t3fa2c1`
/// Indented task lines below another task are its subtasks.
public struct TaskItem: Equatable, Sendable {
    public enum Status: String, CaseIterable, Sendable {
        case open = " "
        case done = "x"
        case cancelled = "-"
        case scheduled = ">"
    }

    public var status: Status
    /// Task text with markers removed. `#tags` stay in the title on purpose so they round-trip.
    public var title: String
    public var dueDate: DateOnly?
    /// Optional time on the due date (`>2026-09-10T14:30`).
    public var dueTime: TimeOfDay?
    /// 0 = none, 1 = `!`, 2 = `!!`, 3 = `!!!`.
    public var priority: Int
    /// The raw content of `@done(...)`, e.g. `2026-09-05 10:00`.
    public var doneStamp: String?
    /// Tags found in the title, without `#`.
    public var tags: [String]
    /// Stable id without the caret, e.g. `t3fa2c1`. Assigned on first sync.
    public var id: String?
    public var indent: String
    public var bullet: String
    /// Index of the line inside the note body (0-based).
    public var lineIndex: Int
    /// Line index of the parent task when this line is indented below another task.
    public var parentLineIndex: Int?

    public init(status: Status = .open,
                title: String,
                dueDate: DateOnly? = nil,
                dueTime: TimeOfDay? = nil,
                priority: Int = 0,
                doneStamp: String? = nil,
                tags: [String] = [],
                id: String? = nil,
                indent: String = "",
                bullet: String = "-",
                lineIndex: Int = -1,
                parentLineIndex: Int? = nil) {
        self.status = status
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = min(max(priority, 0), 3)
        self.doneStamp = doneStamp
        self.tags = tags
        self.id = id
        self.indent = indent
        self.bullet = bullet
        self.lineIndex = lineIndex
        self.parentLineIndex = parentLineIndex
    }

    public var isDone: Bool { status == .done || status == .cancelled }

    public var isSubtask: Bool { parentLineIndex != nil }

    /// Nesting depth from the indentation: two spaces (or a tab, counted as four) per level.
    public var indentLevel: Int {
        var width = 0
        for ch in indent { width += ch == "\t" ? 4 : 1 }
        return width / 2
    }

    /// The due moment as a Date, when a date is set.
    public func dueMoment(calendar: Calendar = .current) -> Date? {
        dueDate?.date(at: dueTime, calendar: calendar)
    }

    public var doneDate: Date? {
        guard let doneStamp else { return nil }
        return DoneStamp.date(from: doneStamp)
    }

    public mutating func markDone(at date: Date = Date()) {
        status = .done
        doneStamp = DoneStamp.string(from: date)
    }

    public mutating func markOpen() {
        status = .open
        doneStamp = nil
    }

    public mutating func markCancelled() {
        status = .cancelled
        doneStamp = nil
    }

    /// The canonical markdown line for this task.
    public var serialized: String {
        var parts: [String] = [title.trimmingCharacters(in: .whitespaces)]
        if priority > 0 { parts.append(String(repeating: "!", count: priority)) }
        if let dueDate { parts.append(">\(dueDate)" + (dueTime.map { "T\($0)" } ?? "")) }
        if status == .done, let doneStamp { parts.append("@done(\(doneStamp))") }
        if let id { parts.append("^\(id)") }
        return "\(indent)\(bullet) [\(status.rawValue)] \(parts.joined(separator: " "))"
    }

    public static func makeID() -> String {
        let hex = "0123456789abcdef"
        var out = "t"
        for _ in 0..<6 { out.append(hex.randomElement()!) }
        return out
    }
}

public enum TaskParser {
    static let lineRegex = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s+\[([ xX>\-])\](?:\s+(.*))?$"#)
    static let idRegex = try! NSRegularExpression(pattern: #"(?<!\S)\^(t[0-9a-f]{4,12})(?!\S)"#)
    static let doneRegex = try! NSRegularExpression(pattern: #"(?<!\S)@done\(([^)]*)\)"#)
    static let dueRegex = try! NSRegularExpression(pattern: #"(?<!\S)>(\d{4}-\d{2}-\d{2})(?:T(\d{1,2}:\d{2}))?(?!\S)"#)
    static let priorityRegex = try! NSRegularExpression(pattern: #"(?<!\S)(!{1,3})(?!\S)"#)
    static let tagRegex = try! NSRegularExpression(pattern: #"(?<!\S)#([\p{L}\p{N}_/\-]+)"#)

    /// Parses a single line. Returns nil when the line is not a task.
    public static func parse(line: String, lineIndex: Int = -1) -> TaskItem? {
        let ns = line as NSString
        guard let m = lineRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let indent = ns.substring(with: m.range(at: 1))
        let bullet = ns.substring(with: m.range(at: 2))
        let mark = ns.substring(with: m.range(at: 3)).lowercased()
        var rest = m.range(at: 4).location == NSNotFound ? "" : ns.substring(with: m.range(at: 4))
        let status = TaskItem.Status(rawValue: mark) ?? .open

        var id: String?
        var doneStamp: String?
        var dueDate: DateOnly?
        var dueTime: TimeOfDay?
        var priority = 0

        rest = extract(idRegex, from: rest) { id = $0 }
        rest = extract(doneRegex, from: rest) { doneStamp = $0.trimmingCharacters(in: .whitespaces) }
        let restNS = rest as NSString
        if let due = dueRegex.firstMatch(in: rest, range: NSRange(location: 0, length: restNS.length)) {
            dueDate = DateOnly(restNS.substring(with: due.range(at: 1)))
            if due.range(at: 2).location != NSNotFound {
                dueTime = TimeOfDay(restNS.substring(with: due.range(at: 2)))
            }
            rest = restNS.replacingCharacters(in: due.range, with: " ")
        }
        rest = extract(priorityRegex, from: rest) { priority = max(priority, $0.count) }

        let title = collapseWhitespace(rest)
        let tags = allCaptures(tagRegex, in: title)
        return TaskItem(status: status, title: title, dueDate: dueDate, dueTime: dueTime, priority: priority,
                        doneStamp: doneStamp, tags: tags, id: id, indent: indent, bullet: bullet, lineIndex: lineIndex)
    }

    /// Parses every task line in a body, ignoring fenced code blocks. Indented tasks below another
    /// task get that task as `parentLineIndex`; a heading ends the nesting.
    public static func parse(text: String) -> [TaskItem] {
        var result: [TaskItem] = []
        var inFence = false
        var stack: [(level: Int, lineIndex: Int)] = []
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if trimmed.hasPrefix("#") {
                stack.removeAll()
                continue
            }
            guard var task = parse(line: String(line), lineIndex: i) else { continue }
            let level = task.indentLevel
            while let top = stack.last, top.level >= level { stack.removeLast() }
            task.parentLineIndex = stack.last?.lineIndex
            stack.append((level, i))
            result.append(task)
        }
        return result
    }

    /// Re-parses a serialized task so derived fields (tags, title) are consistent.
    public static func normalized(_ task: TaskItem) -> TaskItem {
        parse(line: task.serialized, lineIndex: task.lineIndex) ?? task
    }

    // MARK: Helpers

    private static func extract(_ regex: NSRegularExpression, from text: String, _ found: (String) -> Void) -> String {
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var out = ns
        for m in matches.reversed() {
            found(ns.substring(with: m.range(at: 1)))
            out = out.replacingCharacters(in: m.range, with: " ") as NSString
        }
        return out as String
    }

    private static func allCaptures(_ regex: NSRegularExpression, in text: String) -> [String] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }
}

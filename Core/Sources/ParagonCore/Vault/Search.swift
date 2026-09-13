import Foundation

/// A parsed search: free text words and phrases plus `key:value` filters.
///
/// Supported filters: `type:project|area|resource|archive|daily|inbox`, `status:active|on-hold|done|archived`,
/// `tag:web` or `#web`, `area:Health`, `due:overdue|today|week|month|none|any`, `is:open|done|task`,
/// `in:Projects` (path prefix). Quoted phrases match as a whole.
public struct SearchQuery: Equatable, Sendable {
    public enum DueFilter: String, CaseIterable, Sendable { case overdue, today, week, month, none, any }
    public enum TaskFilter: String, CaseIterable, Sendable { case open, done, task }

    public var terms: [String] = []
    public var kinds: Set<ParaKind> = []
    public var statuses: Set<String> = []
    public var tags: Set<String> = []
    public var area: String?
    /// Any of these matches. Sets rather than one value each since build 157, because a row of
    /// tick boxes lets him ask for two at once and a single optional could not hold that.
    public var dues: Set<DueFilter> = []
    public var taskStates: Set<TaskFilter> = []
    public var pathPrefix: String?

    public init() {}

    public var isEmpty: Bool {
        terms.isEmpty && kinds.isEmpty && statuses.isEmpty && tags.isEmpty && area == nil
            && dues.isEmpty && taskStates.isEmpty && pathPrefix == nil
    }

    /// True when the query says something about tasks rather than notes.
    public var wantsTasks: Bool { !dues.isEmpty || !taskStates.isEmpty }

    public static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery()
        for token in tokenize(text) {
            let lower = token.lowercased()
            if token.hasPrefix("#"), token.count > 1 {
                query.tags.insert(String(lower.dropFirst()))
                continue
            }
            guard let colon = token.firstIndex(of: ":"), colon != token.startIndex, !token.hasPrefix("\"") else {
                query.terms.append(token)
                continue
            }
            let key = String(lower[..<colon])
            let value = String(token[token.index(after: colon)...])
            let lowerValue = value.lowercased()
            switch key {
            case "type", "kind":
                if let kind = ParaKind(rawValue: lowerValue) ?? Self.kindAliases[lowerValue] { query.kinds.insert(kind) } else { query.terms.append(token) }
            case "status": query.statuses.insert(lowerValue)
            case "tag", "tags": query.tags.insert(lowerValue.trimmingCharacters(in: .init(charactersIn: "#")))
            case "area": query.area = value
            case "due": if let d = DueFilter(rawValue: lowerValue) { query.dues.insert(d) } else { query.terms.append(token) }
            case "is": if let t = TaskFilter(rawValue: lowerValue) { query.taskStates.insert(t) } else { query.terms.append(token) }
            case "in", "path": query.pathPrefix = value
            default: query.terms.append(token)
            }
        }
        return query
    }

    // MARK: Saying what it means

    /// The query in plain words: "Notes in Projects with the word \u201cplan\u201d."
    ///
    /// Build 157, and the reason for it is his: *"I think it would be better if you could do it
    /// somehow so that you tick in boxes so that you see exactly what your search term is."*
    /// He searched for **done** and got nothing he expected, because the word `done` and the
    /// **Done** tick box are two different questions and the screen never said which one it had
    /// heard. This line says it, every time, above the results.
    ///
    /// It lives in Core, with tests, because it is the one place the meaning of a query is
    /// written down \u2014 and because the labels below are what the tick boxes are drawn from, so
    /// a box and this sentence can never disagree.
    public var summary: String {
        guard !isEmpty else { return "Nothing searched for yet. Write a word, or tick a box." }
        var parts: [String] = []
        if !taskStates.isEmpty {
            parts.append("that are " + SearchQuery.list(taskStates.sorted { $0.rawValue < $1.rawValue }.map { SearchQuery.label(for: $0) }))
        }
        if !dues.isEmpty {
            parts.append(SearchQuery.list(dues.sorted { $0.rawValue < $1.rawValue }.map { SearchQuery.label(for: $0) }))
        }
        if !kinds.isEmpty {
            parts.append("in " + SearchQuery.list(kinds.map(\.displayName).sorted()))
        }
        if !statuses.isEmpty {
            parts.append("marked " + SearchQuery.list(statuses.sorted()))
        }
        if !tags.isEmpty {
            parts.append("tagged " + SearchQuery.list(tags.sorted().map { "#\($0)" }))
        }
        if let area { parts.append("in the area \(area)") }
        if let pathPrefix { parts.append("under \(pathPrefix)") }
        if !terms.isEmpty {
            let quoted = terms.map { "\u{201C}\($0)\u{201D}" }
            parts.append(terms.count == 1 ? "with the word \(quoted[0])" : "with the words " + SearchQuery.list(quoted))
        }
        return (wantsTasks ? "Tasks " : "Notes ") + parts.joined(separator: ", ") + "."
    }

    /// What a tick box for this is called. The box and `summary` read from the same words.
    public static func label(for due: DueFilter) -> String {
        switch due {
        case .overdue: return "overdue"
        case .today: return "due today"
        case .week: return "due this week"
        case .month: return "due this month"
        case .none: return "with no date"
        case .any: return "with a date"
        }
    }

    public static func label(for state: TaskFilter) -> String {
        switch state {
        case .open: return "not done"
        case .done: return "done"
        case .task: return "tasks"
        }
    }

    /// "a", "a and b", "a, b and c".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return items[0] + " and " + items[1]
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }

    private static let kindAliases: [String: ParaKind] = [
        "projects": .project, "areas": .area, "resources": .resource, "archived": .archive,
        "calendar": .daily, "week": .daily, "weekly": .daily, "note": .resource, "goals": .goal,
    ]

    /// Splits on whitespace, keeping quoted phrases together (quotes removed).
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        for ch in text {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if ch.isWhitespace && !inQuotes {
                if !current.isEmpty { tokens.append(current) }
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

/// One matching note with the lines that matched.
public struct SearchHit: Identifiable, Equatable, Sendable {
    public var note: Note
    /// Lines from the body that contain a term (or the first lines when only filters matched).
    public var snippets: [String]
    /// Tasks in the note that satisfy the task part of the query.
    public var tasks: [TaskItem]
    public var score: Int

    public var id: String { note.relativePath }
}

public extension NoteIndex {
    /// Full-text search with filters. Notes are ranked: title matches first, then by number of matching lines.
    func search(_ query: SearchQuery, today: DateOnly = .today(), calendar: Calendar = .current) -> [SearchHit] {
        guard !query.isEmpty else { return [] }
        let terms = query.terms.map { $0.lowercased() }
        var hits: [SearchHit] = []
        for note in notes {
            guard matchesFilters(note, query: query) else { continue }
            let title = note.displayTitle.lowercased()
            let body = note.body.lowercased()
            let titleHits = terms.filter { title.contains($0) }.count
            guard terms.allSatisfy({ title.contains($0) || body.contains($0) }) else { continue }

            var matchingTasks = note.tasks
            if query.wantsTasks {
                matchingTasks = matchingTasks.filter { taskMatches($0, query: query, today: today, calendar: calendar) }
                if !terms.isEmpty {
                    matchingTasks = matchingTasks.filter { task in
                        let t = task.title.lowercased()
                        return terms.contains { t.contains($0) }
                    }
                }
                guard !matchingTasks.isEmpty else { continue }
            } else if !terms.isEmpty {
                matchingTasks = matchingTasks.filter { task in
                    let t = task.title.lowercased()
                    return terms.contains { t.contains($0) }
                }
            }

            var snippets: [String] = []
            if !terms.isEmpty {
                for line in note.lines {
                    let lower = line.lowercased()
                    if terms.contains(where: { lower.contains($0) }) {
                        let clean = line.trimmingCharacters(in: .whitespaces)
                        if !clean.isEmpty && !clean.hasPrefix("#") { snippets.append(clean) }
                    }
                    if snippets.count >= 3 { break }
                }
            }
            // Filter-only queries rank alphabetically; text queries rank title hits, then matching lines and tasks.
            let score = terms.isEmpty ? 0 : titleHits * 100 + snippets.count * 10 + matchingTasks.count
            hits.append(SearchHit(note: note, snippets: snippets, tasks: matchingTasks, score: score))
        }
        return hits.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.note.displayTitle.localizedCaseInsensitiveCompare(b.note.displayTitle) == .orderedAscending
        }
    }

    /// Convenience: parse and search.
    func search(text: String, today: DateOnly = .today()) -> [SearchHit] {
        search(SearchQuery.parse(text), today: today)
    }

    /// Task-level results across the vault for a task query, e.g. `due:overdue is:open`.
    func searchTasks(_ query: SearchQuery, today: DateOnly = .today()) -> [TaskRef] {
        search(query, today: today).flatMap { hit in
            hit.tasks.map { TaskRef(notePath: hit.note.relativePath, noteTitle: hit.note.displayTitle, task: $0) }
        }
    }

    // MARK: Matching

    private func matchesFilters(_ note: Note, query: SearchQuery) -> Bool {
        if !query.kinds.isEmpty && !query.kinds.contains(note.kind) { return false }
        if !query.statuses.isEmpty {
            let status = note.status ?? (note.isArchived ? "archived" : "active")
            let normalized = status.replacingOccurrences(of: " ", with: "-")
            guard query.statuses.contains(normalized) || (normalized == "onhold" && query.statuses.contains("on-hold")) else { return false }
        }
        if !query.tags.isEmpty {
            let noteTags = Set(note.tags.map { $0.lowercased() } + note.tasks.flatMap { $0.tags.map { $0.lowercased() } })
            guard query.tags.isSubset(of: noteTags) else { return false }
        }
        if let area = query.area {
            guard let noteArea = note.area, noteArea.caseInsensitiveCompare(area) == .orderedSame
                    || noteArea.localizedCaseInsensitiveContains(area) else { return false }
        }
        if let prefix = query.pathPrefix {
            guard note.relativePath.lowercased().hasPrefix(prefix.lowercased()) else { return false }
        }
        return true
    }

    /// Ticking two boxes in a row means "either of these", so each set is an **or** and the
    /// sets are **and**ed together: open tasks *or* done tasks, that are also overdue *or* due
    /// today. An empty set asks nothing of that row.
    private func taskMatches(_ task: TaskItem, query: SearchQuery, today: DateOnly, calendar: Calendar) -> Bool {
        if !query.taskStates.isEmpty {
            let matches = query.taskStates.contains { state in
                switch state {
                case .open: return !task.isDone
                case .done: return task.status == .done
                case .task: return true
                }
            }
            guard matches else { return false }
        }
        guard !query.dues.isEmpty else { return true }
        return query.dues.contains { matchesDue($0, task: task, today: today) }
    }

    private func matchesDue(_ due: SearchQuery.DueFilter, task: TaskItem, today: DateOnly) -> Bool {
        switch due {
        case .any: return task.dueDate != nil
        case .none: return task.dueDate == nil
        case .overdue: return task.dueDate.map { $0 < today && !task.isDone } ?? false
        case .today: return task.dueDate == today
        case .week: return task.dueDate.map { WeekRef(containing: today).contains($0) } ?? false
        case .month: return task.dueDate.map { $0.year == today.year && $0.month == today.month } ?? false
        }
    }
}

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
    public var due: DueFilter?
    public var taskFilter: TaskFilter?
    public var pathPrefix: String?

    public init() {}

    public var isEmpty: Bool {
        terms.isEmpty && kinds.isEmpty && statuses.isEmpty && tags.isEmpty && area == nil && due == nil && taskFilter == nil && pathPrefix == nil
    }

    /// True when the query says something about tasks rather than notes.
    public var wantsTasks: Bool { due != nil || taskFilter != nil }

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
            case "due": if let d = DueFilter(rawValue: lowerValue) { query.due = d } else { query.terms.append(token) }
            case "is": if let t = TaskFilter(rawValue: lowerValue) { query.taskFilter = t } else { query.terms.append(token) }
            case "in", "path": query.pathPrefix = value
            default: query.terms.append(token)
            }
        }
        return query
    }

    private static let kindAliases: [String: ParaKind] = [
        "projects": .project, "areas": .area, "resources": .resource, "archived": .archive,
        "calendar": .daily, "week": .daily, "weekly": .daily, "note": .resource,
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

    private func taskMatches(_ task: TaskItem, query: SearchQuery, today: DateOnly, calendar: Calendar) -> Bool {
        switch query.taskFilter {
        case .open?: if task.isDone { return false }
        case .done?: if task.status != .done { return false }
        case .task?, nil: break
        }
        guard let due = query.due else { return true }
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

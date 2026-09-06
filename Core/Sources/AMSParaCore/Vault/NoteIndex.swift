import Foundation

/// A task together with the note it lives in.
public struct TaskRef: Identifiable, Equatable, Sendable {
    public var notePath: String
    public var noteTitle: String
    public var task: TaskItem

    public var id: String { "\(notePath)#\(task.lineIndex)" }

    public init(notePath: String, noteTitle: String, task: TaskItem) {
        self.notePath = notePath
        self.noteTitle = noteTitle
        self.task = task
    }
}

/// In-memory index over all notes: lookup by title, backlinks, tags, tasks and search.
public struct NoteIndex: Sendable {
    public let notes: [Note]
    private let byLowercasedTitle: [String: Note]
    private let byPath: [String: Note]

    public init(notes: [Note]) {
        self.notes = notes
        var titles: [String: Note] = [:]
        var paths: [String: Note] = [:]
        for note in notes {
            paths[note.relativePath] = note
            titles[note.title.lowercased()] = titles[note.title.lowercased()] ?? note
            titles[note.fileName.lowercased()] = titles[note.fileName.lowercased()] ?? note
        }
        self.byLowercasedTitle = titles
        self.byPath = paths
    }

    public func note(path: String) -> Note? { byPath[path] }

    /// Resolves a wikilink or `related:` entry to a note, by relative path, path without extension, or title.
    public func note(matching reference: String) -> Note? {
        let ref = reference.trimmingCharacters(in: .whitespaces)
        if let n = byPath[ref] ?? byPath[ref + ".md"] { return n }
        let last = ref.split(separator: "/").last.map(String.init) ?? ref
        return byLowercasedTitle[last.lowercased()] ?? byLowercasedTitle[ref.lowercased()]
    }

    public func notes(kind: ParaKind) -> [Note] {
        notes.filter { $0.kind == kind }
    }

    public func dailyNote(for date: DateOnly) -> Note? {
        notes.first { $0.kind == .daily && $0.dailyDate == date }
    }

    /// Daily and weekly notes, newest first (a weekly note sorts before the daily note of its Monday).
    public var dailyNotes: [Note] {
        notes(kind: .daily).sorted { a, b in
            let da = a.dailyDate ?? a.weekRef?.monday ?? DateOnly(year: 0, month: 1, day: 1)
            let db = b.dailyDate ?? b.weekRef?.monday ?? DateOnly(year: 0, month: 1, day: 1)
            if da != db { return da > db }
            return a.isWeeklyNote && !b.isWeeklyNote
        }
    }

    /// One next action per active project: the `#next` task, else the first open top-level task.
    public func nextActions() -> [TaskRef] {
        notes(kind: .project)
            .filter { !$0.isArchived && $0.status != "done" && $0.status != "completed" && $0.status != "on hold" }
            .compactMap { note in
                let task = note.nextAction ?? note.tasks.first { !$0.isDone && !$0.isSubtask }
                return task.map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
            }
    }

    /// Open tasks due on exactly this date, across the vault.
    public func openTasks(dueOn date: DateOnly) -> [TaskRef] {
        openTasks().filter { $0.task.dueDate == date }
    }

    /// Notes that reference the given note through `related`, `area` or a wikilink.
    public func backlinks(to target: Note) -> [Note] {
        notes.filter { candidate in
            candidate.relativePath != target.relativePath &&
            candidate.outgoingReferences.contains { note(matching: $0)?.relativePath == target.relativePath }
        }
    }

    /// Reference material that supports a project or area.
    public func resources(for target: Note) -> [Note] {
        backlinks(to: target).filter { $0.kind == .resource }
            + target.outgoingReferences.compactMap(note(matching:)).filter { $0.kind == .resource && $0.relativePath != target.relativePath }
    }

    /// Projects belonging to an area (via `area:` frontmatter or a link).
    public func projects(in area: Note) -> [Note] {
        backlinks(to: area).filter { $0.kind == .project }
    }

    public func notes(tagged tag: String) -> [Note] {
        let t = tag.lowercased().trimmingCharacters(in: .init(charactersIn: "#"))
        return notes.filter { note in
            note.tags.contains { $0.lowercased() == t } || note.tasks.contains { $0.tags.contains { $0.lowercased() == t } }
        }
    }

    public var allTags: [String] {
        var set = Set<String>()
        for note in notes {
            note.tags.forEach { set.insert($0) }
            note.tasks.forEach { $0.tags.forEach { set.insert($0) } }
        }
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func search(_ query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return notes }
        return notes.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.body.localizedCaseInsensitiveContains(q) }
    }

    /// Open tasks across the vault, optionally limited to those due on or before a date.
    public func openTasks(dueOnOrBefore limit: DateOnly? = nil, includeArchived: Bool = false) -> [TaskRef] {
        var refs: [TaskRef] = []
        for note in notes where includeArchived || !note.isArchived {
            for task in note.openTasks {
                if let limit {
                    guard let due = task.dueDate, due <= limit else { continue }
                }
                refs.append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        return refs.sorted { a, b in
            switch (a.task.dueDate, b.task.dueDate) {
            case let (x?, y?):
                if x != y { return x < y }
                switch (a.task.dueTime, b.task.dueTime) {
                case let (s?, t?) where s != t: return s < t
                case (nil, _?): return false
                case (_?, nil): return true
                default: break
                }
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
            if a.task.priority != b.task.priority { return a.task.priority > b.task.priority }
            return a.noteTitle.localizedCaseInsensitiveCompare(b.noteTitle) == .orderedAscending
        }
    }
}

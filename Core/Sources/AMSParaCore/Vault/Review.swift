import Foundation

/// Health of one project or area, computed for the weekly review.
public struct ProjectHealth: Identifiable, Equatable, Sendable {
    public enum Flag: String, CaseIterable, Sendable {
        case noNextAction
        case overdueTasks
        case pastDue
        case stale
        case reviewDue
        case onHold

        public var label: String {
            switch self {
            case .noNextAction: return "No next action"
            case .overdueTasks: return "Overdue tasks"
            case .pastDue: return "Past its due date"
            case .stale: return "No changes recently"
            case .reviewDue: return "Review due"
            case .onHold: return "On hold"
            }
        }
    }

    public var note: Note
    public var openTaskCount: Int
    public var overdueTaskCount: Int
    public var completedLast7Days: Int
    public var daysSinceModified: Int?
    public var daysSinceReview: Int?
    public var flags: [Flag]

    public var id: String { note.relativePath }
    public var needsAttention: Bool { !flags.isEmpty && flags != [.onHold] }
}

/// Everything the weekly review screen needs.
public struct ReviewReport: Equatable, Sendable {
    public var today: DateOnly
    public var inboxOpenTasks: Int
    public var projects: [ProjectHealth]
    public var areas: [ProjectHealth]
    public var completedLast7Days: Int
    public var overdueTasks: [TaskRef]

    public var projectsNeedingAttention: [ProjectHealth] { projects.filter(\.needsAttention) }
}

public extension NoteIndex {
    /// Tasks completed on or after a date, judged by their `@done(...)` stamp.
    func tasksCompleted(since start: DateOnly) -> [TaskRef] {
        var refs: [TaskRef] = []
        for note in notes {
            for task in note.tasks where task.status == .done {
                guard let stamp = task.doneStamp, let day = DateOnly(String(stamp.prefix(10))), day >= start else { continue }
                refs.append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        return refs
    }

    func health(of note: Note, today: DateOnly, config: VaultConfig, calendar: Calendar = .current) -> ProjectHealth {
        let open = note.openTasks
        let overdue = open.filter { ($0.dueDate.map { $0 < today }) ?? false }
        let weekAgo = today.adding(days: -7, calendar: calendar)
        let completed = note.tasks.filter { task in
            guard task.status == .done, let stamp = task.doneStamp, let day = DateOnly(String(stamp.prefix(10))) else { return false }
            return day >= weekAgo
        }.count
        let daysSinceModified = note.modifiedAt.map { today.days(since: DateOnly($0, calendar: calendar), calendar: calendar) }
        let daysSinceReview = note.reviewedDate.map { today.days(since: $0, calendar: calendar) }

        var flags: [ProjectHealth.Flag] = []
        let status = note.status ?? "active"
        if status == "on-hold" || status == "onhold" || status == "paused" || status == "someday" {
            flags.append(.onHold)
        } else {
            if open.isEmpty { flags.append(.noNextAction) }
            if !overdue.isEmpty { flags.append(.overdueTasks) }
            if let due = note.dueDate, due < today { flags.append(.pastDue) }
            if let days = daysSinceModified, days >= config.staleProjectDays { flags.append(.stale) }
            if let days = daysSinceReview {
                if days >= config.reviewIntervalDays { flags.append(.reviewDue) }
            } else {
                flags.append(.reviewDue)
            }
        }
        return ProjectHealth(note: note, openTaskCount: open.count, overdueTaskCount: overdue.count,
                             completedLast7Days: completed, daysSinceModified: daysSinceModified,
                             daysSinceReview: daysSinceReview, flags: flags)
    }

    func review(today: DateOnly = .today(), config: VaultConfig, calendar: Calendar = .current) -> ReviewReport {
        let active = { (note: Note) in !note.isArchived && note.status != "done" && note.status != "completed" }
        let projects = notes(kind: .project).filter(active).map { health(of: $0, today: today, config: config, calendar: calendar) }
            .sorted { a, b in
                if a.needsAttention != b.needsAttention { return a.needsAttention }
                return a.note.title.localizedCaseInsensitiveCompare(b.note.title) == .orderedAscending
            }
        let areas = notes(kind: .area).filter(active).map { health(of: $0, today: today, config: config, calendar: calendar) }
        let inbox = notes(kind: .inbox).first?.openTasks.count ?? 0
        let completed = tasksCompleted(since: today.adding(days: -7, calendar: calendar)).count
        let overdue = openTasks(dueOnOrBefore: today.adding(days: -1, calendar: calendar))
        return ReviewReport(today: today, inboxOpenTasks: inbox, projects: projects, areas: areas,
                            completedLast7Days: completed, overdueTasks: overdue)
    }
}

public extension DateOnly {
    func adding(days: Int, calendar: Calendar = .current) -> DateOnly {
        guard let base = date(calendar: calendar), let shifted = calendar.date(byAdding: .day, value: days, to: base) else { return self }
        return DateOnly(shifted, calendar: calendar)
    }

    /// Whole days from `other` to `self` (positive when `self` is later).
    func days(since other: DateOnly, calendar: Calendar = .current) -> Int {
        guard let a = other.date(calendar: calendar), let b = date(calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }
}

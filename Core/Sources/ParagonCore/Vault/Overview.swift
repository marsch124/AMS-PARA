import Foundation

/// What one day looks like across the whole vault.
public struct DayOverview: Identifiable, Equatable, Sendable {
    public var date: DateOnly
    public var dailyNotePath: String?
    /// Open tasks due on this day, anywhere in the vault.
    public var due: [TaskRef]
    /// Tasks completed on this day (by their `@done` stamp).
    public var completed: [TaskRef]
    /// Open tasks written in the daily note without a date.
    public var undated: [TaskRef]

    public var id: DateOnly { date }
    public var overdueCount: Int { due.filter { $0.task.dueDate.map { $0 < .today() } ?? false }.count }
    public var isEmpty: Bool { dailyNotePath == nil && due.isEmpty && completed.isEmpty && undated.isEmpty }
}

public struct WeekOverview: Equatable, Sendable {
    public var week: WeekRef
    public var weeklyNotePath: String?
    public var days: [DayOverview]

    public var dueCount: Int { days.reduce(0) { $0 + $1.due.count } }
    public var completedCount: Int { days.reduce(0) { $0 + $1.completed.count } }
}

public struct MonthOverview: Equatable, Sendable {
    public var month: MonthRef
    public var days: [DayOverview]

    public var dueCount: Int { days.reduce(0) { $0 + $1.due.count } }
    public var completedCount: Int { days.reduce(0) { $0 + $1.completed.count } }
}

public extension NoteIndex {
    func dayOverview(for date: DateOnly) -> DayOverview {
        let daily = dailyNote(for: date)
        var undated: [TaskRef] = []
        if let daily {
            undated = daily.openTasks.filter { $0.dueDate == nil }
                .map { TaskRef(notePath: daily.relativePath, noteTitle: daily.displayTitle, task: $0) }
        }
        return DayOverview(date: date,
                           dailyNotePath: daily?.relativePath,
                           due: openTasks(dueOn: date),
                           completed: tasksCompleted(on: date),
                           undated: undated)
    }

    func weekOverview(for week: WeekRef) -> WeekOverview {
        WeekOverview(week: week, weeklyNotePath: weeklyNote(for: week)?.relativePath, days: week.days.map(dayOverview(for:)))
    }

    func monthOverview(for month: MonthRef) -> MonthOverview {
        MonthOverview(month: month, days: month.days.map(dayOverview(for:)))
    }

    /// Tasks whose `@done` stamp falls on a day.
    func tasksCompleted(on date: DateOnly) -> [TaskRef] {
        var refs: [TaskRef] = []
        for note in notes {
            for task in note.tasks where task.status == .done {
                guard let stamp = task.doneStamp, DateOnly(String(stamp.prefix(10))) == date else { continue }
                refs.append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        return refs
    }

    func weeklyNote(for week: WeekRef) -> Note? {
        notes.first { $0.kind == .daily && $0.weekRef == week }
    }
}

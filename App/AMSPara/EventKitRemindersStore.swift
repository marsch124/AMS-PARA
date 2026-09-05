import Foundation
import EventKit
import AMSParaCore

/// Apple Reminders through EventKit. Each Reminders list is a "calendar" of type `.reminder`.
final class EventKitRemindersStore: RemindersStore {
    private let eventStore = EKEventStore()

    func requestAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        default:
            return try await eventStore.requestFullAccessToReminders()
        }
    }

    private func calendar(named name: String) -> EKCalendar? {
        eventStore.calendars(for: .reminder).first { $0.title == name }
    }

    func listNames() async throws -> [String] {
        eventStore.calendars(for: .reminder).map(\.title)
    }

    func ensureList(named name: String) async throws {
        guard calendar(named: name) == nil else { return }
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = name
        guard let source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .calDAV })
            ?? eventStore.sources.first(where: { $0.sourceType == .local }) else {
            throw RemindersStoreError.underlying("No Reminders account is available to create the list \"\(name)\".")
        }
        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)
    }

    func reminders(inList name: String) async throws -> [ReminderRecord] {
        guard let calendar = calendar(named: name) else { return [] }
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let items: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        return items.map(record(from:))
    }

    func create(_ draft: ReminderRecord) async throws -> ReminderRecord {
        try await ensureList(named: draft.listName)
        guard let calendar = calendar(named: draft.listName) else {
            throw RemindersStoreError.listNotFound(draft.listName)
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        apply(draft, to: reminder)
        try eventStore.save(reminder, commit: true)
        return record(from: reminder)
    }

    func update(_ record: ReminderRecord) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: record.identifier) as? EKReminder else {
            throw RemindersStoreError.reminderNotFound(record.identifier)
        }
        if reminder.calendar?.title != record.listName {
            try await ensureList(named: record.listName)
            if let calendar = calendar(named: record.listName) {
                reminder.calendar = calendar
            }
        }
        apply(record, to: reminder)
        try eventStore.save(reminder, commit: true)
    }

    func delete(identifier: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try eventStore.remove(reminder, commit: true)
    }

    // MARK: Mapping

    private func apply(_ record: ReminderRecord, to reminder: EKReminder) {
        reminder.title = record.title
        reminder.notes = record.notes
        reminder.priority = Self.ekPriority(from: record.priority)
        if let due = record.dueDate {
            var components = due.dateComponents
            components.calendar = Calendar.current
            reminder.dueDateComponents = components
        } else {
            reminder.dueDateComponents = nil
        }
        if record.isCompleted {
            reminder.completionDate = record.completedAt ?? reminder.completionDate ?? Date()
        } else {
            reminder.isCompleted = false
        }
    }

    private func record(from reminder: EKReminder) -> ReminderRecord {
        ReminderRecord(identifier: reminder.calendarItemIdentifier,
                       listName: reminder.calendar?.title ?? "",
                       title: reminder.title ?? "",
                       isCompleted: reminder.isCompleted,
                       completedAt: reminder.completionDate,
                       dueDate: reminder.dueDateComponents.flatMap { DateOnly(components: $0) },
                       priority: Self.priority(fromEK: reminder.priority),
                       notes: reminder.notes,
                       lastModified: reminder.lastModifiedDate)
    }

    /// EventKit: 0 none, 1 high … 9 low. Notes: 0 none, 1 `!` … 3 `!!!`.
    static func priority(fromEK value: Int) -> Int {
        switch value {
        case 0: return 0
        case 1...4: return 3
        case 5: return 2
        default: return 1
        }
    }

    static func ekPriority(from priority: Int) -> Int {
        switch priority {
        case 3: return 1
        case 2: return 5
        case 1: return 9
        default: return 0
        }
    }
}

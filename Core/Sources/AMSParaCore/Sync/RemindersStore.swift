import Foundation

/// A reminder as seen by the sync engine. Priority is normalized to 0 (none) ... 3 (highest),
/// matching `!`, `!!`, `!!!` in notes.
public struct ReminderRecord: Equatable, Sendable {
    public var identifier: String
    public var listName: String
    public var title: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var dueDate: DateOnly?
    public var dueTime: TimeOfDay?
    public var priority: Int
    public var notes: String?
    public var lastModified: Date?

    public init(identifier: String = "",
                listName: String,
                title: String,
                isCompleted: Bool = false,
                completedAt: Date? = nil,
                dueDate: DateOnly? = nil,
                dueTime: TimeOfDay? = nil,
                priority: Int = 0,
                notes: String? = nil,
                lastModified: Date? = nil) {
        self.identifier = identifier
        self.listName = listName
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.dueTime = dueDate == nil ? nil : dueTime
        self.priority = min(max(priority, 0), 3)
        self.notes = notes
        self.lastModified = lastModified
    }
}

public enum RemindersStoreError: Error, LocalizedError {
    case accessDenied
    case listNotFound(String)
    case reminderNotFound(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Access to Reminders was not granted."
        case .listNotFound(let name): return "Reminders list not found: \(name)"
        case .reminderNotFound(let id): return "Reminder not found: \(id)"
        case .underlying(let message): return message
        }
    }
}

/// Abstraction over Apple Reminders (EventKit in the app, in-memory in tests).
public protocol RemindersStore: AnyObject {
    func listNames() async throws -> [String]
    func ensureList(named name: String) async throws
    func reminders(inList name: String) async throws -> [ReminderRecord]
    /// Creates a reminder and returns it with its store identifier filled in.
    func create(_ draft: ReminderRecord) async throws -> ReminderRecord
    func update(_ record: ReminderRecord) async throws
    func delete(identifier: String) async throws
}

/// Simple store used by tests and previews.
public final class InMemoryRemindersStore: RemindersStore {
    public private(set) var lists: [String] = []
    public private(set) var records: [String: ReminderRecord] = [:]
    public var now: () -> Date = { Date() }
    private var counter = 0
    /// Test hooks: something that happens while the engine waits on Reminders, and simulated failures.
    public var beforeFetch: (() throws -> Void)?
    public var failNextCreate = false
    public var failNextUpdate = false

    public init(lists: [String] = []) {
        self.lists = lists
    }

    public func listNames() async throws -> [String] { lists }

    public func ensureList(named name: String) async throws {
        if !lists.contains(name) { lists.append(name) }
    }

    public func reminders(inList name: String) async throws -> [ReminderRecord] {
        if let beforeFetch { self.beforeFetch = nil; try beforeFetch() }
        return records.values.filter { $0.listName == name }.sorted { $0.identifier < $1.identifier }
    }

    public func create(_ draft: ReminderRecord) async throws -> ReminderRecord {
        if failNextCreate { failNextCreate = false; throw RemindersStoreError.reminderNotFound("simulated failure") }
        try await ensureList(named: draft.listName)
        counter += 1
        var record = draft
        record.identifier = "rem-\(counter)"
        record.lastModified = now()
        records[record.identifier] = record
        return record
    }

    public func update(_ record: ReminderRecord) async throws {
        if failNextUpdate { failNextUpdate = false; throw RemindersStoreError.reminderNotFound("simulated failure") }
        guard records[record.identifier] != nil else { throw RemindersStoreError.reminderNotFound(record.identifier) }
        try await ensureList(named: record.listName)
        var updated = record
        updated.lastModified = now()
        records[record.identifier] = updated
    }

    public func delete(identifier: String) async throws {
        records[identifier] = nil
    }

    // Test helpers that simulate the user editing in Apple Reminders.

    /// Adds a reminder as if the user created it in the Reminders app.
    @discardableResult
    public func simulateUserCreate(list: String, title: String, dueDate: DateOnly? = nil, dueTime: TimeOfDay? = nil,
                                   priority: Int = 0, completed: Bool = false) async throws -> ReminderRecord {
        try await create(ReminderRecord(listName: list, title: title, isCompleted: completed,
                                        completedAt: completed ? now() : nil, dueDate: dueDate, dueTime: dueTime, priority: priority))
    }

    public func simulateUserEdit(identifier: String, _ edit: (inout ReminderRecord) -> Void) {
        guard var record = records[identifier] else { return }
        edit(&record)
        record.lastModified = now()
        records[identifier] = record
    }

    public func record(withMarkerFor taskID: String) -> ReminderRecord? {
        records.values.first { SyncEngine.markerTaskID(in: $0.notes) == taskID }
    }
}

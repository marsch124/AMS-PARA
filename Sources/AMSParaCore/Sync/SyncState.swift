import Foundation

/// The link between one task line and one reminder, plus what both looked like after the last sync.
public struct TaskLink: Codable, Equatable, Sendable {
    public var taskID: String
    public var reminderID: String
    public var notePath: String
    public var listName: String
    public var lastTaskFingerprint: String
    public var lastReminderFingerprint: String
    public var lastSyncedAt: Date

    public init(taskID: String, reminderID: String, notePath: String, listName: String,
                lastTaskFingerprint: String, lastReminderFingerprint: String, lastSyncedAt: Date) {
        self.taskID = taskID
        self.reminderID = reminderID
        self.notePath = notePath
        self.listName = listName
        self.lastTaskFingerprint = lastTaskFingerprint
        self.lastReminderFingerprint = lastReminderFingerprint
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Persisted per device (reminder identifiers are device local in EventKit).
public struct SyncState: Codable, Equatable, Sendable {
    public var version = 1
    public var links: [String: TaskLink] = [:]
    public var lastRun: Date?

    public init() {}

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// What one sync run did.
public struct SyncReport: Equatable, Sendable {
    public var startedAt: Date
    public var finishedAt: Date?
    public var remindersCreated = 0
    public var remindersUpdated = 0
    public var remindersDeleted = 0
    public var tasksCreated = 0
    public var tasksUpdated = 0
    public var tasksCancelled = 0
    public var idsAssigned = 0
    public var notesSynced = 0
    public var conflicts: [String] = []
    public var warnings: [String] = []

    public init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }

    public var changeCount: Int {
        remindersCreated + remindersUpdated + remindersDeleted + tasksCreated + tasksUpdated + tasksCancelled
    }

    public var summary: String {
        var parts: [String] = []
        if remindersCreated > 0 { parts.append("\(remindersCreated) reminder\(remindersCreated == 1 ? "" : "s") created") }
        if remindersUpdated > 0 { parts.append("\(remindersUpdated) updated") }
        if remindersDeleted > 0 { parts.append("\(remindersDeleted) deleted") }
        if tasksCreated > 0 { parts.append("\(tasksCreated) task\(tasksCreated == 1 ? "" : "s") added to notes") }
        if tasksUpdated > 0 { parts.append("\(tasksUpdated) task\(tasksUpdated == 1 ? "" : "s") updated in notes") }
        if tasksCancelled > 0 { parts.append("\(tasksCancelled) cancelled") }
        if !conflicts.isEmpty { parts.append("\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s")") }
        if !warnings.isEmpty { parts.append("\(warnings.count) warning\(warnings.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "Everything in sync (\(notesSynced) notes)" : parts.joined(separator: ", ")
    }
}

import Foundation

public enum ConflictPolicy: String, Codable, CaseIterable, Sendable {
    /// When both the note and the reminder changed since the last sync, the note wins.
    case noteWins
    /// When both changed, the reminder wins.
    case reminderWins
}

/// Per-vault settings, stored in `.ams-para/config.json` inside the vault.
public struct VaultConfig: Codable, Equatable, Sendable {
    public var projectsFolder = "Projects"
    public var areasFolder = "Areas"
    public var resourcesFolder = "Resources"
    public var archiveFolder = "Archive"
    public var templatesFolder = "Templates"
    public var calendarFolder = "Calendar"
    public var inboxFile = "Inbox.md"
    /// Reminders list that mirrors the Inbox note.
    public var inboxListName = "Inbox"
    /// Reminders list shared by all daily notes. New reminders in it land in today's daily note.
    public var dailyNotesListName = "Daily Notes"
    /// Mirror tasks written in daily notes.
    public var syncDailyNotes = true
    /// A project without any change for this many days is flagged in the weekly review.
    public var staleProjectDays = 14
    /// Projects not reviewed for this many days are flagged in the weekly review.
    public var reviewIntervalDays = 7
    public var conflictPolicy: ConflictPolicy = .noteWins
    /// Mirror tasks of Area notes as well as Project notes.
    public var syncAreas = true
    /// Create Reminders lists that do not exist yet.
    public var createMissingLists = true
    /// Import reminders that are already completed but were never linked to a task.
    public var importCompletedReminders = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case projectsFolder, areasFolder, resourcesFolder, archiveFolder, templatesFolder, calendarFolder, inboxFile, inboxListName
        case dailyNotesListName, syncDailyNotes, staleProjectDays, reviewIntervalDays
        case conflictPolicy, syncAreas, createMissingLists, importCompletedReminders
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = VaultConfig()
        projectsFolder = try c.decodeIfPresent(String.self, forKey: .projectsFolder) ?? d.projectsFolder
        areasFolder = try c.decodeIfPresent(String.self, forKey: .areasFolder) ?? d.areasFolder
        resourcesFolder = try c.decodeIfPresent(String.self, forKey: .resourcesFolder) ?? d.resourcesFolder
        archiveFolder = try c.decodeIfPresent(String.self, forKey: .archiveFolder) ?? d.archiveFolder
        templatesFolder = try c.decodeIfPresent(String.self, forKey: .templatesFolder) ?? d.templatesFolder
        inboxFile = try c.decodeIfPresent(String.self, forKey: .inboxFile) ?? d.inboxFile
        inboxListName = try c.decodeIfPresent(String.self, forKey: .inboxListName) ?? d.inboxListName
        calendarFolder = try c.decodeIfPresent(String.self, forKey: .calendarFolder) ?? d.calendarFolder
        dailyNotesListName = try c.decodeIfPresent(String.self, forKey: .dailyNotesListName) ?? d.dailyNotesListName
        syncDailyNotes = try c.decodeIfPresent(Bool.self, forKey: .syncDailyNotes) ?? d.syncDailyNotes
        staleProjectDays = try c.decodeIfPresent(Int.self, forKey: .staleProjectDays) ?? d.staleProjectDays
        reviewIntervalDays = try c.decodeIfPresent(Int.self, forKey: .reviewIntervalDays) ?? d.reviewIntervalDays
        conflictPolicy = try c.decodeIfPresent(ConflictPolicy.self, forKey: .conflictPolicy) ?? d.conflictPolicy
        syncAreas = try c.decodeIfPresent(Bool.self, forKey: .syncAreas) ?? d.syncAreas
        createMissingLists = try c.decodeIfPresent(Bool.self, forKey: .createMissingLists) ?? d.createMissingLists
        importCompletedReminders = try c.decodeIfPresent(Bool.self, forKey: .importCompletedReminders) ?? d.importCompletedReminders
    }

    public func folder(for kind: ParaKind) -> String? {
        switch kind {
        case .project: return projectsFolder
        case .area: return areasFolder
        case .resource: return resourcesFolder
        case .archive: return archiveFolder
        case .daily: return calendarFolder
        case .inbox: return nil
        }
    }
}

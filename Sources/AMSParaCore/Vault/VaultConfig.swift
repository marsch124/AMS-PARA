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
    public var inboxFile = "Inbox.md"
    /// Reminders list that mirrors the Inbox note.
    public var inboxListName = "Inbox"
    public var conflictPolicy: ConflictPolicy = .noteWins
    /// Mirror tasks of Area notes as well as Project notes.
    public var syncAreas = true
    /// Create Reminders lists that do not exist yet.
    public var createMissingLists = true
    /// Import reminders that are already completed but were never linked to a task.
    public var importCompletedReminders = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case projectsFolder, areasFolder, resourcesFolder, archiveFolder, templatesFolder, inboxFile, inboxListName
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
        case .inbox: return nil
        }
    }
}

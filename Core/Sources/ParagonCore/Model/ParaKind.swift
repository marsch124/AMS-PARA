import Foundation

/// The PARA buckets plus the Inbox note.
public enum ParaKind: String, CaseIterable, Codable, Hashable, Sendable {
    case inbox
    case project
    case area
    case resource
    case archive
    /// NotePlan style daily note in `Calendar/YYYYMMDD.md`.
    case daily
    /// A goal above PARA: the reason projects and areas exist. Never synced to Reminders.
    case goal

    public var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .project: return "Projects"
        case .area: return "Areas"
        case .resource: return "Resources"
        case .archive: return "Archive"
        case .daily: return "Calendar"
        case .goal: return "Goals"
        }
    }

    /// Value used for the `type:` frontmatter key.
    public var frontmatterType: String { rawValue }

    /// Kinds whose tasks are mirrored to Apple Reminders.
    public var isTaskKind: Bool {
        switch self {
        case .inbox, .project, .area, .daily: return true
        case .resource, .archive, .goal: return false
        }
    }
}

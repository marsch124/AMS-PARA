import Foundation

/// One tag and how much of the vault carries it.
public struct TagUse: Identifiable, Equatable, Sendable {
    public let tag: String
    /// Notes whose own `tags:` line carries it.
    public let noteCount: Int
    /// Open tasks carrying it, anywhere.
    public let openTaskCount: Int
    /// Tasks carrying it that are done or cancelled (`TaskItem.isDone` covers both).
    public let finishedTaskCount: Int

    public var id: String { tag }
    public var total: Int { noteCount + openTaskCount + finishedTaskCount }
}

public extension NoteIndex {
    /// Every tag in the vault with its counts, most used first, then by name.
    ///
    /// One pass over the notes rather than one pass per tag: a vault with 60 tags and 400
    /// notes would otherwise be 24,000 scans every time the list is drawn.
    func tagUses() -> [TagUse] {
        var notesFor: [String: Int] = [:]
        var openFor: [String: Int] = [:]
        var finishedFor: [String: Int] = [:]
        var spelling: [String: String] = [:]

        func remember(_ tag: String) -> String {
            let key = tag.lowercased()
            if spelling[key] == nil { spelling[key] = tag }
            return key
        }

        for note in notes {
            for tag in Set(note.tags) {
                notesFor[remember(tag), default: 0] += 1
            }
            for task in note.tasks {
                for tag in task.tags {
                    let key = remember(tag)
                    if task.isDone {
                        finishedFor[key, default: 0] += 1
                    } else {
                        openFor[key, default: 0] += 1
                    }
                }
            }
        }

        return spelling.keys.map { key in
            TagUse(tag: spelling[key] ?? key,
                   noteCount: notesFor[key] ?? 0,
                   openTaskCount: openFor[key] ?? 0,
                   finishedTaskCount: finishedFor[key] ?? 0)
        }
        .sorted { a, b in
            a.total == b.total
                ? a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
                : a.total > b.total
        }
    }

    /// Notes whose own `tags:` line carries this tag. A note whose *tasks* carry it is not
    /// one of these — that is what `tasksTagged(_:)` is for, and mixing the two is what made
    /// `notes(tagged:)` unusable for a list you can read.
    func notesTagged(_ tag: String) -> [Note] {
        let wanted = Self.normalized(tag)
        return notes.filter { note in note.tags.contains { $0.lowercased() == wanted } }
    }

    /// Every task carrying this tag, open ones first, each with the note it sits in.
    func tasksTagged(_ tag: String, includeFinished: Bool = true) -> [TaskRef] {
        let wanted = Self.normalized(tag)
        var refs: [TaskRef] = []
        for note in notes {
            for task in note.tasks where task.tags.contains(where: { $0.lowercased() == wanted }) {
                guard includeFinished || !task.isDone else { continue }
                refs.append(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
        }
        return refs.sorted { a, b in
            if a.task.isDone != b.task.isDone { return !a.task.isDone }
            return a.noteTitle.localizedCaseInsensitiveCompare(b.noteTitle) == .orderedAscending
        }
    }

    /// A tag as it is compared: lower case, without a leading `#`.
    static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .init(charactersIn: "#"))
            .lowercased()
    }
}

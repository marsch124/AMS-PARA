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

    public init(tag: String, noteCount: Int = 0, openTaskCount: Int = 0, finishedTaskCount: Int = 0) {
        self.tag = tag
        self.noteCount = noteCount
        self.openTaskCount = openTaskCount
        self.finishedTaskCount = finishedTaskCount
    }

    public var id: String { tag }
    public var total: Int { noteCount + openTaskCount + finishedTaskCount }
    /// Made but not yet put on anything. Only a tag from `Vault.knownTags()` can be this.
    public var isUnused: Bool { total == 0 }
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

// MARK: Renaming and removing a tag

public extension Note {
    /// This note with one tag renamed, or removed when `new` is nil. Returns nil when the note
    /// never carried it, so a caller can write only the files that really changed — the same
    /// shape as `retargeting(_:to:)` for a renamed note.
    ///
    /// Both places a tag can live are rewritten: the `tags:` line, and `#tag` in the text. The
    /// text is matched with the *same* pattern the task parser uses, so what is renamed is
    /// exactly what the app counts as a tag — a `## Heading` is untouched, and `#travelling`
    /// is not a match for `#travel`.
    func changingTag(_ old: String, to new: String?) -> Note? {
        let wanted = NoteIndex.normalized(old)
        guard !wanted.isEmpty else { return nil }
        var updated = self
        var changed = false

        let existing = tags
        if existing.contains(where: { $0.lowercased() == wanted }) {
            var seen = Set<String>()
            var rebuilt: [String] = []
            for tag in existing {
                let replacement = tag.lowercased() == wanted ? new : tag
                guard let replacement, !replacement.isEmpty else { continue }
                if seen.insert(replacement.lowercased()).inserted { rebuilt.append(replacement) }
            }
            updated.frontmatter.set("tags", list: rebuilt)
            changed = true
        }

        if let rewritten = Self.rewrite(body, tag: wanted, to: new) {
            updated.body = rewritten
            changed = true
        }
        return changed ? updated : nil
    }

    /// The body with `#old` rewritten, or nil when it does not appear.
    private static func rewrite(_ text: String, tag old: String, to new: String?) -> String? {
        guard let regex = tagPattern(old) else { return nil }
        var lines = text.components(separatedBy: "\n")
        var changed = false
        let template = new.map { "#" + NSRegularExpression.escapedTemplate(for: $0) } ?? ""
        for (index, line) in lines.enumerated() {
            let ns = line as NSString
            let whole = NSRange(location: 0, length: ns.length)
            guard regex.firstMatch(in: line, options: [], range: whole) != nil else { continue }
            var rewritten = regex.stringByReplacingMatches(in: line, options: [], range: whole, withTemplate: template)
            // Taking a tag out leaves "Book the ferry  #summer" or a trailing space.
            if new == nil { rewritten = tidySpaces(rewritten) }
            lines[index] = rewritten
            changed = true
        }
        return changed ? lines.joined(separator: "\n") : nil
    }

    /// `#tag`, as the task parser reads one: not glued to the word before it, and not matching
    /// a longer tag that starts with the same letters.
    private static func tagPattern(_ tag: String) -> NSRegularExpression? {
        let escaped = NSRegularExpression.escapedPattern(for: tag)
        return try? NSRegularExpression(pattern: #"(?<!\S)#"# + escaped + #"(?![\p{L}\p{N}_/\-])"#,
                                        options: [.caseInsensitive])
    }

    /// Keeps the indent, squeezes the gap a removed tag left, drops a trailing space.
    private static func tidySpaces(_ line: String) -> String {
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        var rest = String(line.dropFirst(leading.count))
        while rest.contains("  ") { rest = rest.replacingOccurrences(of: "  ", with: " ") }
        return String(leading) + rest.trimmingCharacters(in: .whitespaces)
    }
}

public extension Vault {
    /// Renames a tag everywhere in the vault, or removes it when `new` is nil.
    ///
    /// Work notes are deliberately left alone: they are kept out of `allNotes()` on purpose
    /// (build 112), so nothing about them is ever shown in the Tags screen either.
    @discardableResult
    func changeTag(_ old: String, to new: String?) throws -> MultiSaveResult {
        saveEach(try allNotes()) { $0.changingTag(old, to: new) }
    }

    // MARK: Tags made but not used yet

    /// A tag with nothing on it has nowhere to live in a markdown vault, so the few that have
    /// been made and not used yet are kept here, beside the vault's other bookkeeping.
    var knownTagsURL: URL { stateFolderURL.appendingPathComponent("tags.json") }

    func knownTags() -> [String] {
        guard let data = try? Data(contentsOf: knownTagsURL),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }

    func rememberTag(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "#"))
        guard !clean.isEmpty else { return }
        var list = knownTags()
        guard !list.contains(where: { $0.lowercased() == clean.lowercased() }) else { return }
        list.append(clean)
        writeKnownTags(list)
    }

    func forgetTag(_ tag: String) {
        let wanted = NoteIndex.normalized(tag)
        let list = knownTags().filter { $0.lowercased() != wanted }
        writeKnownTags(list)
    }

    private func writeKnownTags(_ list: [String]) {
        try? FileManager.default.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: knownTagsURL, options: .atomic)
    }
}

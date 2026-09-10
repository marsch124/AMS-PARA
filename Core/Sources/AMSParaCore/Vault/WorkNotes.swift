import Foundation

/// A second, separate set of notes, kept in the vault's `Work` folder.
///
/// It is deliberately outside everything else. `allNotes()` walks the PARA folders and the
/// Inbox and never comes here, so work notes are absent from Today, All actions, the Map, the
/// weekly review, the main search and — because the sync engine starts from `allNotes()` —
/// from Reminders. Nothing has to remember to exclude them: they are simply not in the list
/// the rest of the app is built on.
///
/// They are ordinary markdown all the same, so `save`, `rename`, `trash` and the backups work
/// on them exactly as they do on any other note.
public extension Vault {
    var workURL: URL { rootURL.appendingPathComponent(config.workFolder, isDirectory: true) }

    /// True when the folder is there at all: until the first work note is made, the vault
    /// carries no sign of this.
    var hasWorkFolder: Bool { FileManager.default.fileExists(atPath: workURL.path) }

    func workNote(at relativePath: String) throws -> Note {
        try loadNote(relativePath: relativePath)
    }

    /// The work notes, newest change first — no arranging, no `order:`; a list of notes.
    func workNotes() -> [Note] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: workURL.path) else { return [] }
        var result: [Note] = []
        for name in entries {
            // An iCloud stub is the file, not yet delivered: ask for it, as everywhere else.
            if let real = CloudFiles.realName(ofPlaceholder: name), real.lowercased().hasSuffix(".md") {
                CloudFiles.startDownload(workURL.appendingPathComponent(real))
                continue
            }
            guard !name.hasPrefix("."), name.lowercased().hasSuffix(".md") else { continue }
            if let note = try? loadNote(relativePath: "\(config.workFolder)/\(name)") { result.append(note) }
        }
        return result.sorted { a, b in
            (a.modifiedAt ?? .distantPast) == (b.modifiedAt ?? .distantPast)
                ? a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
                : (a.modifiedAt ?? .distantPast) > (b.modifiedAt ?? .distantPast)
        }
    }

    /// Makes a work note. The folder is created here rather than by `bootstrap`, so a vault
    /// belonging to someone who never uses this has no `Work` folder in it.
    @discardableResult
    func createWorkNote(title: String) throws -> Note {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = Self.sanitizeFileName(clean)
        guard !clean.isEmpty, !fileName.isEmpty else { throw VaultError.invalidTitle }
        try FileManager.default.createDirectory(at: workURL, withIntermediateDirectories: true)
        let relativePath = "\(config.workFolder)/\(fileName).md"
        guard !CloudFiles.exists(url(for: relativePath)) else {
            throw VaultError.noteAlreadyExists(relativePath)
        }
        let text = """
        ---
        title: \(clean)
        type: work
        created: \(DateOnly.today())
        ---
        # \(clean)


        """
        let note = Note(relativePath: relativePath, kind: .resource, text: text, modifiedAt: nil)
        return try save(note)
    }

    /// True for a path inside the work folder — the one question the app layer asks to know
    /// which list a note belongs to.
    func isWorkPath(_ relativePath: String) -> Bool {
        relativePath.hasPrefix("\(config.workFolder)/")
    }

    /// Work notes whose title or text matches, for the search that lives inside the section.
    /// The main search never sees these, which is the point of them.
    func searchWorkNotes(_ query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return workNotes() }
        return workNotes().filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) || $0.body.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

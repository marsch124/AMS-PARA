import Foundation

/// A note that was deleted and can still be put back. It lives as a file in the vault's
/// hidden `Deleted` folder, carrying `deleted:` and `deleted-from:` in its frontmatter,
/// where nothing scans it and nothing syncs it.
public struct DeletedNote: Identifiable, Equatable, Sendable {
    /// The file's name inside the Deleted folder, which is also its identity.
    public let fileName: String
    public let title: String
    public let kind: ParaKind
    /// Where it was when it was deleted, so "Put back" knows where back is.
    public let originalPath: String
    public let deletedAt: Date

    public var id: String { fileName }

    public init(fileName: String, title: String, kind: ParaKind, originalPath: String, deletedAt: Date) {
        self.fileName = fileName
        self.title = title
        self.kind = kind
        self.originalPath = originalPath
        self.deletedAt = deletedAt
    }
}

public extension Vault {
    var deletedFolderURL: URL { stateFolderURL.appendingPathComponent("Deleted", isDirectory: true) }

    static var deletedStampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Deleted notes, most recently deleted first.
    func deletedNotes() -> [DeletedNote] {
        let formatter = Vault.deletedStampFormatter
        let names = (try? FileManager.default.contentsOfDirectory(atPath: deletedFolderURL.path)) ?? []
        return names.filter { $0.hasSuffix(".md") }.compactMap { name -> DeletedNote? in
            guard let text = try? String(contentsOf: deletedFolderURL.appendingPathComponent(name), encoding: .utf8) else { return nil }
            let front = Frontmatter.parse(text).frontmatter
            let path = front.string("deleted-from") ?? ""
            let kind = front.string("type").flatMap(ParaKind.init(rawValue:)) ?? .resource
            return DeletedNote(fileName: name,
                               title: front.string("title") ?? String(name.dropLast(3)),
                               kind: kind,
                               originalPath: path,
                               deletedAt: front.string("deleted").flatMap { formatter.date(from: $0) } ?? .distantPast)
        }
        .sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Moves a note into the Deleted folder. The file keeps its text; two keys are added so
    /// it knows when it went and where it came from.
    func moveToDeleted(_ note: Note, at date: Date = Date()) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: deletedFolderURL, withIntermediateDirectories: true)
        var deleted = note
        deleted.frontmatter.set("deleted", Vault.deletedStampFormatter.string(from: date))
        deleted.frontmatter.set("deleted-from", note.relativePath)

        let stamp = Vault.sanitizeFileName(Vault.deletedStampFormatter.string(from: date).replacingOccurrences(of: ":", with: ""))
        var name = "\(stamp) \(note.fileName).md"
        var attempt = 2
        while manager.fileExists(atPath: deletedFolderURL.appendingPathComponent(name).path) {
            name = "\(stamp) \(note.fileName) \(attempt).md"
            attempt += 1
        }
        try deleted.text.write(to: deletedFolderURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try manager.removeItem(at: url(for: note.relativePath))
    }

    /// Puts a deleted note back where it was, or beside it when that name is taken again.
    @discardableResult
    func restore(_ deleted: DeletedNote) throws -> Note {
        let source = deletedFolderURL.appendingPathComponent(deleted.fileName)
        let text = try String(contentsOf: source, encoding: .utf8)
        var note = Note(relativePath: deleted.originalPath, kind: deleted.kind, text: text)
        note.frontmatter.remove("deleted")
        note.frontmatter.remove("deleted-from")

        var target = deleted.originalPath
        if target.isEmpty {
            let folder = config.folder(for: deleted.kind) ?? config.resourcesFolder
            target = "\(folder)/\(Vault.sanitizeFileName(deleted.title)).md"
        }
        if FileManager.default.fileExists(atPath: url(for: target).path) {
            let base = String(target.dropLast(3))
            var candidate = "\(base) (restored).md"
            var attempt = 2
            while FileManager.default.fileExists(atPath: url(for: candidate).path) {
                candidate = "\(base) (restored \(attempt)).md"
                attempt += 1
            }
            target = candidate
        }
        note.relativePath = target
        note.modifiedAt = nil
        let saved = try save(note, force: true)
        try FileManager.default.removeItem(at: source)
        return saved
    }

    /// Removes one deleted note for good.
    func purge(_ deleted: DeletedNote) throws {
        try FileManager.default.removeItem(at: deletedFolderURL.appendingPathComponent(deleted.fileName))
    }

    /// Clears out everything deleted longer ago than this, so the folder does not grow forever.
    func purgeDeleted(olderThan days: Int, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        for deleted in deletedNotes() where deleted.deletedAt < cutoff {
            try? purge(deleted)
        }
    }
}

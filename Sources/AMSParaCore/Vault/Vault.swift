import Foundation

public enum VaultError: Error, LocalizedError, Equatable {
    case notADirectory(String)
    case noteNotFound(String)
    case noteAlreadyExists(String)
    case invalidTitle

    public var errorDescription: String? {
        switch self {
        case .notADirectory(let p): return "\(p) is not a folder."
        case .noteNotFound(let p): return "Note not found: \(p)"
        case .noteAlreadyExists(let p): return "A note already exists at \(p)"
        case .invalidTitle: return "The title is empty or contains only invalid characters."
        }
    }
}

/// A folder of markdown notes laid out as PARA: Projects, Areas, Resources, Archive, plus `Inbox.md`.
public final class Vault {
    public let rootURL: URL
    public private(set) var config: VaultConfig
    private let fm = FileManager.default

    public static let stateFolderName = ".ams-para"

    public init(rootURL: URL) throws {
        let url = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw VaultError.notADirectory(url.path)
        }
        self.rootURL = url
        self.config = VaultConfig()
        self.config = (try? loadConfig()) ?? VaultConfig()
    }

    // MARK: Config and state files

    public var stateFolderURL: URL { rootURL.appendingPathComponent(Self.stateFolderName, isDirectory: true) }
    public var configURL: URL { stateFolderURL.appendingPathComponent("config.json") }

    public func loadConfig() throws -> VaultConfig {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(VaultConfig.self, from: data)
    }

    public func save(config: VaultConfig) throws {
        try fm.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: configURL, options: .atomic)
        self.config = config
    }

    public func syncStateURL(deviceID: String) -> URL {
        stateFolderURL.appendingPathComponent("sync-state-\(Self.sanitizeFileName(deviceID)).json")
    }

    public func loadSyncState(deviceID: String) -> SyncState {
        guard let data = try? Data(contentsOf: syncStateURL(deviceID: deviceID)),
              let state = try? SyncState.decoder.decode(SyncState.self, from: data) else { return SyncState() }
        return state
    }

    public func save(syncState: SyncState, deviceID: String) throws {
        try fm.createDirectory(at: stateFolderURL, withIntermediateDirectories: true)
        try SyncState.encoder.encode(syncState).write(to: syncStateURL(deviceID: deviceID), options: .atomic)
    }

    // MARK: Layout

    /// Creates the PARA folders, the Inbox note and default templates when missing.
    public func bootstrap() throws {
        for kind in [ParaKind.project, .area, .resource, .archive] {
            if let folder = config.folder(for: kind) {
                try fm.createDirectory(at: rootURL.appendingPathComponent(folder, isDirectory: true), withIntermediateDirectories: true)
            }
        }
        try fm.createDirectory(at: templatesURL, withIntermediateDirectories: true)
        let inbox = rootURL.appendingPathComponent(config.inboxFile)
        if !fm.fileExists(atPath: inbox.path) {
            try Templates.inbox.write(to: inbox, atomically: true, encoding: .utf8)
        }
        for (name, content) in Templates.defaults {
            let url = templatesURL.appendingPathComponent("\(name).md")
            if !fm.fileExists(atPath: url.path) {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        if !fm.fileExists(atPath: configURL.path) {
            try save(config: config)
        }
    }

    public var templatesURL: URL { rootURL.appendingPathComponent(config.templatesFolder, isDirectory: true) }

    public func url(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    public func relativePath(for url: URL) -> String? {
        let root = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard path.hasPrefix(root) else { return nil }
        return String(path.dropFirst(root.count))
    }

    public func kind(forRelativePath path: String) -> ParaKind? {
        if path == config.inboxFile { return .inbox }
        guard let first = path.split(separator: "/").first.map(String.init) else { return nil }
        for kind in [ParaKind.project, .area, .resource, .archive] where config.folder(for: kind) == first {
            return kind
        }
        return nil
    }

    // MARK: Reading

    public func allNotes() throws -> [Note] {
        var notes: [Note] = []
        if fm.fileExists(atPath: url(for: config.inboxFile).path) {
            notes.append(try loadNote(relativePath: config.inboxFile))
        }
        for kind in [ParaKind.project, .area, .resource, .archive] {
            notes.append(contentsOf: try notes(kind: kind))
        }
        return notes
    }

    public func notes(kind: ParaKind) throws -> [Note] {
        if kind == .inbox {
            return fm.fileExists(atPath: url(for: config.inboxFile).path) ? [try loadNote(relativePath: config.inboxFile)] : []
        }
        guard let folder = config.folder(for: kind) else { return [] }
        let folderURL = rootURL.appendingPathComponent(folder, isDirectory: true)
        guard fm.fileExists(atPath: folderURL.path),
              let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var result: [Note] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md",
                  (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let rel = relativePath(for: fileURL) else { continue }
            result.append(try loadNote(relativePath: rel))
        }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func loadNote(relativePath: String) throws -> Note {
        let fileURL = url(for: relativePath)
        guard fm.fileExists(atPath: fileURL.path) else { throw VaultError.noteNotFound(relativePath) }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let modified = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let kind = kind(forRelativePath: relativePath) ?? .resource
        return Note(relativePath: relativePath, kind: kind, text: text, modifiedAt: modified)
    }

    // MARK: Writing

    public func save(_ note: Note) throws {
        let fileURL = url(for: note.relativePath)
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try note.text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Creates a note from the kind's template (if present) or a minimal frontmatter block.
    public func createNote(kind: ParaKind, title: String, extraFrontmatter: [(String, String)] = []) throws -> Note {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = Self.sanitizeFileName(cleanTitle)
        guard !fileName.isEmpty, let folder = config.folder(for: kind) else { throw VaultError.invalidTitle }
        let relativePath = "\(folder)/\(fileName).md"
        guard !fm.fileExists(atPath: url(for: relativePath).path) else { throw VaultError.noteAlreadyExists(relativePath) }

        var text = templateText(for: kind) ?? Templates.minimal(kind: kind)
        text = Templates.fill(text, title: cleanTitle, date: DateOnly.today())
        var note = Note(relativePath: relativePath, kind: kind, text: text, modifiedAt: Date())
        note.frontmatter.set("title", cleanTitle)
        if note.frontmatter.string("type") == nil { note.frontmatter.set("type", kind.frontmatterType) }
        if note.frontmatter.string("created") == nil { note.frontmatter.set("created", DateOnly.today().description) }
        for (key, value) in extraFrontmatter { note.frontmatter.set(key, value) }
        try save(note)
        return note
    }

    public func templateText(for kind: ParaKind) -> String? {
        let name: String
        switch kind {
        case .project: name = "Project"
        case .area: name = "Area"
        case .resource: name = "Resource"
        case .inbox, .archive: return nil
        }
        return try? String(contentsOf: templatesURL.appendingPathComponent("\(name).md"), encoding: .utf8)
    }

    /// Moves a note into the Archive folder (keeping its original folder as a sub-folder) and marks it archived.
    @discardableResult
    public func archive(_ note: Note) throws -> Note {
        guard note.kind != .archive, note.kind != .inbox else { return note }
        var archived = note
        archived.frontmatter.set("status", "archived")
        archived.frontmatter.set("archived", DateOnly.today().description)
        archived.frontmatter.set("sync", "false")
        let target = "\(config.archiveFolder)/\(note.relativePath)"
        archived.relativePath = target
        archived.kind = .archive
        try save(archived)
        try fm.removeItem(at: url(for: note.relativePath))
        return archived
    }

    public func delete(_ note: Note) throws {
        try fm.removeItem(at: url(for: note.relativePath))
    }

    public static func sanitizeFileName(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t").union(.controlCharacters)
        let cleaned = title.unicodeScalars.map { forbidden.contains($0) ? " " : Character($0) }
        return String(cleaned).split(separator: " ").joined(separator: " ").trimmingCharacters(in: .init(charactersIn: ". "))
    }
}

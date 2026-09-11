import Foundation

/// Where a quick capture lands.
public enum CaptureTarget: Codable, Equatable, Hashable, Sendable {
    case inbox
    case today
    case note(path: String)

    public var label: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today's note"
        case .note(let path): return (path.split(separator: "/").last.map(String.init) ?? path).replacingOccurrences(of: ".md", with: "")
        }
    }

    /// `inbox`, `today` or a note path, as used in the URL scheme.
    public var queryValue: String {
        switch self {
        case .inbox: return "inbox"
        case .today: return "today"
        case .note(let path): return path
        }
    }

    public init(queryValue: String?) {
        switch queryValue?.lowercased() {
        case nil, "", "inbox": self = .inbox
        case "today": self = .today
        default: self = .note(path: queryValue ?? "")
        }
    }
}

/// One captured thought: text, an optional link, and where it should go.
public struct CaptureItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var url: URL?
    public var target: CaptureTarget
    /// true: `- [ ] text` under Tasks. false: `- text` under Notes.
    public var asTask: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, url: URL? = nil, target: CaptureTarget = .inbox, asTask: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.url = url
        self.target = target
        self.asTask = asTask
        self.createdAt = createdAt
    }

    public static let urlScheme = "amspara"

    /// Parses `amspara://capture?text=...&url=...&target=inbox|today|<note path>&note=1`.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme, url.host?.lowercased() == "capture",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        let text = (value("text") ?? value("title") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Only web and mail links are kept; anything else (file:, javascript:) is dropped.
        let link = value("url").flatMap(URL.init(string:)).flatMap { url -> URL? in
            ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") ? url : nil
        }
        guard !text.isEmpty || link != nil else { return nil }
        let asNote = ["1", "true", "yes"].contains((value("note") ?? "").lowercased())
        self.init(text: text.isEmpty ? (link?.absoluteString ?? "") : text, url: link,
                  target: CaptureTarget(queryValue: value("target")), asTask: !asNote)
    }

    /// The URL that reproduces this capture, for Shortcuts and tests.
    public var captureURL: URL? {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "capture"
        var items = [URLQueryItem(name: "text", value: text), URLQueryItem(name: "target", value: target.queryValue)]
        if let url { items.append(URLQueryItem(name: "url", value: url.absoluteString)) }
        if !asTask { items.append(URLQueryItem(name: "note", value: "1")) }
        components.queryItems = items
        return components.url
    }

    /// The markdown line body: the text plus the link when the text does not already contain it.
    public var lineText: String {
        let clean = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        guard let url else { return TaskParser.collapseWhitespace(clean) }
        if clean.contains(url.absoluteString) { return TaskParser.collapseWhitespace(clean) }
        if clean.isEmpty { return "[\(url.host ?? url.absoluteString)](\(url.absoluteString))" }
        return TaskParser.collapseWhitespace(clean) + " [\(url.host ?? "link")](\(url.absoluteString))"
    }
}

/// A file that share extensions and other processes append to, drained by the app.
/// One JSON object per line so concurrent appends never corrupt earlier entries.
public struct CaptureOutbox: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public func append(_ item: CaptureItem) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var line = try Self.encoder.encode(item)
        line.append(contentsOf: [0x0A])
        // O_APPEND makes each line land at the end even when the app and the share
        // extension write at the same moment.
        let fd = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: line)
    }

    /// Items waiting in the outbox, oldest first. Lines that fail to decode are skipped.
    public func peek() -> [CaptureItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return data.split(separator: 0x0A).compactMap { try? Self.decoder.decode(CaptureItem.self, from: $0) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Returns the waiting items and empties the outbox. The file is renamed first, so an
    /// item the share extension appends meanwhile lands in a fresh outbox and is not lost.
    public func drain() -> [CaptureItem] {
        let taken = fileURL.deletingLastPathComponent().appendingPathComponent("capture-outbox.\(UUID().uuidString).jsonl")
        guard (try? FileManager.default.moveItem(at: fileURL, to: taken)) != nil else { return [] }
        defer { try? FileManager.default.removeItem(at: taken) }
        guard let data = try? Data(contentsOf: taken) else { return [] }
        return data.split(separator: 0x0A).compactMap { try? Self.decoder.decode(CaptureItem.self, from: $0) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Puts items back, e.g. ones that could not be filed yet.
    public func requeue(_ items: [CaptureItem]) {
        for item in items { try? append(item) }
    }
}

public extension Vault {
    /// Appends a capture to its target note (falling back to the Inbox) and saves it.
    @discardableResult
    func capture(_ item: CaptureItem, today: DateOnly = .today()) throws -> Note {
        var note: Note
        switch item.target {
        case .inbox:
            note = try inboxNote()
        case .today:
            note = try dailyNote(for: today)
        case .note(let path):
            // The path may come from a link another app opened: it has to be a note inside the vault.
            if isNotePath(path), let existing = try? loadNote(relativePath: path) {
                note = existing
            } else {
                note = try inboxNote()
            }
        }
        if item.asTask {
            note.append(task: TaskParser.normalized(TaskItem(title: item.lineText)))
        } else {
            note.appendLine("- " + item.lineText, under: "Notes")
        }
        try save(note)
        return note
    }

    func inboxNote() throws -> Note {
        if !FileManager.default.fileExists(atPath: url(for: config.inboxFile).path) {
            try Templates.inbox.write(to: url(for: config.inboxFile), atomically: true, encoding: .utf8)
        }
        return try loadNote(relativePath: config.inboxFile)
    }
}

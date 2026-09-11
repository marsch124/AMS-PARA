import Foundation

/// A named block of task lines kept in `Templates/Snippets.md`, ready to be dropped into a
/// note. Anything in `{{double braces}}` is filled in when it is used.
public struct Snippet: Identifiable, Equatable, Sendable {
    public let name: String
    /// The lines as written, placeholders and all.
    public let lines: [String]

    public var id: String { name }

    public init(name: String, lines: [String]) {
        self.name = name
        self.lines = lines
    }

    /// The placeholders this snippet asks for: everything in braces that the app cannot
    /// work out itself, in the order they appear, each named once.
    public var questions: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in Snippets.placeholders(in: lines.joined(separator: "\n"))
        where !Snippets.automatic.contains(name.lowercased()) && seen.insert(name.lowercased()).inserted {
            result.append(name)
        }
        return result
    }
}

public enum Snippets {
    /// The file inside `Templates/` that holds them.
    public static let fileName = "Snippets"

    /// Placeholders the app fills in without asking.
    public static let automatic: Set<String> = ["date", "today", "tomorrow", "week"]

    /// Splits the file into snippets: one per `## Heading`, everything under it its lines.
    /// Blank lines at the ends are dropped; prose above the first heading is the file's
    /// own explanation and is ignored.
    public static func parse(_ text: String) -> [Snippet] {
        var snippets: [Snippet] = []
        var name: String?
        var lines: [String] = []

        func close() {
            guard let open = name else { return }
            let trimmed = trimmingBlankEnds(lines)
            if !trimmed.isEmpty { snippets.append(Snippet(name: open, lines: trimmed)) }
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                close()
                name = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                lines = []
            } else if name != nil {
                lines.append(raw)
            }
        }
        close()
        return snippets
    }

    /// The snippet's lines with every placeholder replaced: the dates the app knows, then
    /// whatever was typed in. A placeholder nobody answered is left as it is rather than
    /// leaving a hole in the task.
    public static func filled(_ snippet: Snippet, answers: [String: String] = [:],
                              today: DateOnly = .today()) -> [String] {
        let automatic = [
            "date": today.description,
            "today": today.description,
            "tomorrow": today.adding(days: 1).description,
            "week": today.adding(days: 7).description,
        ]
        return snippet.lines.map { line in
            var filled = line
            for name in placeholders(in: line) {
                let value = answers[name] ?? answers[name.lowercased()] ?? automatic[name.lowercased()]
                guard let value, !value.isEmpty else { continue }
                filled = filled.replacingOccurrences(of: "{{\(name)}}", with: value)
            }
            return filled
        }
    }

    /// Every `{{name}}` in the text, in order, as written.
    public static func placeholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}") else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
    }

    private static func trimmingBlankEnds(_ lines: [String]) -> [String] {
        var result = lines
        while let first = result.first, first.trimmingCharacters(in: .whitespaces).isEmpty { result.removeFirst() }
        while let last = result.last, last.trimmingCharacters(in: .whitespaces).isEmpty { result.removeLast() }
        return result
    }
}

/// One file in the vault's `Templates` folder. Its `type:` line says what kind of note it
/// makes, so you can keep several project templates side by side; the one named after the
/// kind ("Project") is the one used unless another is chosen.
public struct TemplateFile: Identifiable, Equatable, Sendable {
    public let name: String
    /// The kind of note it makes, from its own `type:` line. Nil for Snippets and for
    /// anything that does not say.
    public let kind: ParaKind?

    public var id: String { name }
    public var isSnippets: Bool { name == Snippets.fileName }
    /// True for the file a new note of that kind uses unless you pick another.
    public var isDefault: Bool { kind.map { name == TemplateFile.defaultName(for: $0) } ?? false }

    public init(name: String, kind: ParaKind?) {
        self.name = name
        self.kind = kind
    }

    /// The file a kind falls back to: "Project", "Area", and so on.
    public static func defaultName(for kind: ParaKind) -> String {
        switch kind {
        case .project: return "Project"
        case .area: return "Area"
        case .resource: return "Resource"
        case .daily: return "Daily"
        case .goal: return "Goal"
        case .archive: return "Archive"
        case .inbox: return "Inbox"
        }
    }
}

public extension Vault {
    var snippetsURL: URL { templatesURL.appendingPathComponent("\(Snippets.fileName).md") }

    /// Every template in the folder with the kind it makes, defaults first and then by name.
    func templates() -> [TemplateFile] {
        templateNames().map { name in
            let type = templateText(named: name).map { Frontmatter.parse($0).frontmatter.string("type") ?? "" } ?? ""
            return TemplateFile(name: name, kind: ParaKind(rawValue: type))
        }
    }

    /// The templates that make one kind of note, the default one first.
    func templates(for kind: ParaKind) -> [TemplateFile] {
        templates().filter { $0.kind == kind }.sorted { a, b in
            a.isDefault == b.isDefault ? a.name < b.name : a.isDefault
        }
    }

    /// Starts a new template from the default for its kind, so it opens with something in it.
    @discardableResult
    func createTemplate(named name: String, kind: ParaKind) throws -> TemplateFile {
        let clean = Self.sanitizeFileName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !clean.isEmpty else { throw VaultError.invalidTitle }
        let target = templatesURL.appendingPathComponent("\(clean).md")
        guard !CloudFiles.exists(target) else {
            throw VaultError.noteAlreadyExists("Templates/\(clean).md")
        }
        let seed = templateText(named: TemplateFile.defaultName(for: kind))
            ?? Templates.minimal(kind: kind)
        try saveTemplate(named: clean, text: seed)
        return TemplateFile(name: clean, kind: kind)
    }

    func renameTemplate(named name: String, to newName: String) throws {
        let clean = Self.sanitizeFileName(newName.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !clean.isEmpty, clean != name else { throw VaultError.invalidTitle }
        let target = templatesURL.appendingPathComponent("\(clean).md")
        guard !CloudFiles.exists(target) else {
            throw VaultError.noteAlreadyExists("Templates/\(clean).md")
        }
        try FileManager.default.moveItem(at: templatesURL.appendingPathComponent("\(name).md"), to: target)
    }

    func deleteTemplate(named name: String) throws {
        try FileManager.default.removeItem(at: templatesURL.appendingPathComponent("\(name).md"))
    }

    func snippets() -> [Snippet] {
        guard let text = try? String(contentsOf: snippetsURL, encoding: .utf8) else { return [] }
        return Snippets.parse(text)
    }

    /// The template files, by name without the extension, in a sensible reading order.
    func templateNames() -> [String] {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: templatesURL.path)) ?? [])
            .filter { $0.hasSuffix(".md") }
            .map { String($0.dropLast(3)) }
        let preferred = ["Project", "Area", "Resource", "Goal", "Daily", "Weekly", Snippets.fileName]
        return names.sorted { a, b in
            let ia = preferred.firstIndex(of: a) ?? preferred.count
            let ib = preferred.firstIndex(of: b) ?? preferred.count
            return ia == ib ? a < b : ia < ib
        }
    }

    func templateText(named name: String) -> String? {
        try? String(contentsOf: templatesURL.appendingPathComponent("\(name).md"), encoding: .utf8)
    }

    func saveTemplate(named name: String, text: String) throws {
        try FileManager.default.createDirectory(at: templatesURL, withIntermediateDirectories: true)
        try text.write(to: templatesURL.appendingPathComponent("\(name).md"), atomically: true, encoding: .utf8)
    }
}

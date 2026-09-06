import Foundation

public enum FrontmatterValue: Equatable, Sendable {
    case string(String)
    case list([String])
}

/// A small, order-preserving YAML subset: `key: value`, `key: [a, b]` and block lists.
/// Lines it does not understand (comments, nested blocks, keys with spaces) are kept
/// verbatim and written back in place, so saving never loses what another editor wrote.
public struct Frontmatter: Equatable, Sendable {
    enum Entry: Equatable, Sendable {
        case key(String)
        case raw(String)
    }

    private var order: [Entry] = []
    private var storage: [String: FrontmatterValue] = [:]

    public init() {}

    public var keys: [String] {
        order.compactMap { if case .key(let k) = $0 { return k } else { return nil } }
    }

    public var isEmpty: Bool { order.isEmpty }

    public subscript(key: String) -> FrontmatterValue? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil { order.append(.key(key)) }
                storage[key] = newValue
            } else {
                storage[key] = nil
                order.removeAll { $0 == .key(key) }
            }
        }
    }

    private mutating func appendRaw(_ line: String) {
        order.append(.raw(line))
    }

    public func string(_ key: String) -> String? {
        switch storage[key] {
        case .string(let s): return s.isEmpty ? nil : s
        case .list(let l): return l.first
        case nil: return nil
        }
    }

    public func list(_ key: String) -> [String] {
        switch storage[key] {
        case .string(let s):
            return s.isEmpty ? [] : [s]
        case .list(let l):
            return l
        case nil:
            return []
        }
    }

    public func bool(_ key: String) -> Bool? {
        guard let s = string(key)?.lowercased() else { return nil }
        if ["true", "yes", "on", "1"].contains(s) { return true }
        if ["false", "no", "off", "0"].contains(s) { return false }
        return nil
    }

    public mutating func set(_ key: String, _ value: String) {
        self[key] = .string(value)
    }

    public mutating func set(_ key: String, list: [String]) {
        self[key] = .list(list)
    }

    public mutating func remove(_ key: String) {
        self[key] = nil
    }

    // MARK: Parsing

    /// Splits a document into frontmatter (if it starts with a `---` fence) and body.
    /// A leading `---` that turns out to enclose prose (a horizontal rule) is left as body.
    public static func parse(_ text: String) -> (frontmatter: Frontmatter, body: String) {
        let cleaned = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return (Frontmatter(), cleaned)
        }
        guard let closing = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---" }) else {
            return (Frontmatter(), cleaned)
        }
        var fm = Frontmatter()
        var pendingListKey: String?
        for raw in lines[1..<closing] {
            let line = raw.trimmingCharacters(in: .init(charactersIn: "\r"))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                fm.appendRaw(line)
                continue
            }
            if let key = pendingListKey, let item = listItem(line) {
                var items = fm.list(key)
                items.append(item)
                fm.set(key, list: items)
                continue
            }
            let indented = line.first?.isWhitespace == true
            guard let colon = line.firstIndex(of: ":"), !indented else {
                // An indented line belongs to a nested block we keep as written; an
                // unindented line without a colon is prose, so this is not frontmatter.
                if indented { fm.appendRaw(line); continue }
                return (Frontmatter(), cleaned)
            }
            pendingListKey = nil
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains(" "), !key.contains("\t") else {
                fm.appendRaw(line)
                continue
            }
            let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if rest.isEmpty {
                fm.set(key, list: [])
                pendingListKey = key
            } else if rest.hasPrefix("[") && rest.hasSuffix("]") {
                fm.set(key, list: splitInlineList(String(rest.dropFirst().dropLast())))
            } else {
                fm.set(key, unquote(rest))
            }
        }
        let body = lines[(closing + 1)...].joined(separator: "\n")
        return (fm, body)
    }

    /// Splits `a, "b, c", 'd'` into items, honouring quotes.
    static func splitInlineList(_ inner: String) -> [String] {
        var items: [String] = []
        var current = ""
        var quote: Character?
        for ch in inner {
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == "," {
                items.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        items.append(current)
        return items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func listItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") else { return nil }
        return unquote(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
    }

    private static func unquote(_ s: String) -> String {
        guard s.count >= 2 else { return s }
        if s.hasPrefix("\"") && s.hasSuffix("\"") {
            return String(s.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        if s.hasPrefix("'") && s.hasSuffix("'") {
            return String(s.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        return s
    }

    // MARK: Serialization

    /// Returns the `---` fenced block including the trailing newline, or an empty string.
    public func serialized() -> String {
        guard !isEmpty else { return "" }
        var out = "---\n"
        for entry in order {
            switch entry {
            case .raw(let line):
                out += line + "\n"
            case .key(let key):
                switch storage[key] {
                case .string(let s):
                    out += "\(key): \(Self.quoteIfNeeded(s))\n"
                case .list(let items):
                    // An empty value is written as `key:` so templates invite plain text, not typing inside `[]`.
                    out += items.isEmpty ? "\(key):\n" : "\(key): [\(items.map(Self.quoteIfNeeded).joined(separator: ", "))]\n"
                case nil:
                    break
                }
            }
        }
        out += "---\n"
        return out
    }

    private static func quoteIfNeeded(_ s: String) -> String {
        let needsQuotes = s.isEmpty
            || s.contains(": ")
            || s.contains(", ")
            || s.hasSuffix(":")
            || ["[", "]", "{", "}", "#", "\"", "'", "&", "*", "!", "|", ">", "%", "@", "`"].contains(where: { s.hasPrefix($0) })
        guard needsQuotes else { return s }
        return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

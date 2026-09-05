import Foundation

public enum FrontmatterValue: Equatable, Sendable {
    case string(String)
    case list([String])
}

/// A small, order-preserving YAML subset: `key: value`, `key: [a, b]` and block lists.
public struct Frontmatter: Equatable, Sendable {
    public private(set) var keys: [String] = []
    private var storage: [String: FrontmatterValue] = [:]

    public init() {}

    public var isEmpty: Bool { keys.isEmpty }

    public subscript(key: String) -> FrontmatterValue? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil { keys.append(key) }
                storage[key] = newValue
            } else {
                storage[key] = nil
                keys.removeAll { $0 == key }
            }
        }
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
    public static func parse(_ text: String) -> (frontmatter: Frontmatter, body: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (Frontmatter(), text)
        }
        guard let closing = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (Frontmatter(), text)
        }
        var fm = Frontmatter()
        var pendingListKey: String?
        for raw in lines[1..<closing] {
            let line = raw.trimmingCharacters(in: .init(charactersIn: "\r"))
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                continue
            }
            if let key = pendingListKey, let item = listItem(line) {
                var items = fm.list(key)
                items.append(item)
                fm.set(key, list: items)
                continue
            }
            pendingListKey = nil
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains(" ") else { continue }
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
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    // MARK: Serialization

    /// Returns the `---` fenced block including the trailing newline, or an empty string.
    public func serialized() -> String {
        guard !isEmpty else { return "" }
        var out = "---\n"
        for key in keys {
            switch storage[key] {
            case .string(let s):
                out += "\(key): \(Self.quoteIfNeeded(s))\n"
            case .list(let items):
                out += "\(key): [\(items.map(Self.quoteIfNeeded).joined(separator: ", "))]\n"
            case nil:
                break
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

import Foundation

/// Everything about `[[links]]` that is text rather than interface: where a half-typed link
/// starts, which titles match it, what the text looks like once one is chosen, and which link
/// a click landed on. The editor does the drawing; these decisions are made here, where they
/// can be tested.
public enum WikiLinks {
    /// A `[[` that has been typed and not yet closed, with what has been typed since.
    public struct Draft: Equatable, Sendable {
        /// Where the `[[` starts, in UTF-16 offsets to match the text views.
        public let start: Int
        /// The cursor, i.e. where what has been typed so far ends.
        public let cursor: Int
        /// What has been typed between the brackets.
        public let query: String

        public init(start: Int, cursor: Int, query: String) {
            self.start = start
            self.cursor = cursor
            self.query = query
        }
    }

    /// The link being typed at the cursor, or nil.
    ///
    /// Only a `[[` on the cursor's own line counts, and only when nothing has closed it since:
    /// a stray `[[` two paragraphs up must not turn every later keystroke into a search. A
    /// `]]` after the cursor is fine — that is what completing an existing link looks like.
    public static func draft(in text: String, cursor: Int) -> Draft? {
        let ns = text as NSString
        guard cursor >= 0, cursor <= ns.length else { return nil }
        var i = cursor - 1
        var seenNewline = false
        while i >= 1 {
            let here = ns.character(at: i)
            let before = ns.character(at: i - 1)
            if here == 0x000A { seenNewline = true }
            if seenNewline { return nil }
            // "]]" between the brackets and the cursor closes it: nothing is being typed.
            if here == 0x005D, before == 0x005D { return nil }
            if here == 0x005B, before == 0x005B {
                let start = i - 1
                let query = ns.substring(with: NSRange(location: start + 2, length: cursor - start - 2))
                // A newline inside would mean the brackets were left behind on an earlier line.
                guard !query.contains("\n") else { return nil }
                return Draft(start: start, cursor: cursor, query: query)
            }
            i -= 1
        }
        return nil
    }

    /// Titles worth offering for what has been typed: the ones that start with it first, then
    /// the ones that merely contain it, each group in the order they were given (the caller
    /// decides what "sensible order" means — most recently changed, say). An empty query
    /// offers everything, which is what makes `[[` on its own useful.
    public static func suggestions(for query: String, among titles: [String], limit: Int = 8) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(titles.prefix(limit)) }
        var starting: [String] = []
        var containing: [String] = []
        for title in titles {
            if title.lowercased().hasPrefix(trimmed.lowercased()) {
                starting.append(title)
            } else if title.localizedCaseInsensitiveContains(trimmed) {
                containing.append(title)
            }
        }
        return Array((starting + containing).prefix(limit))
    }

    /// The text with the half-typed link replaced by the finished one, and where the cursor
    /// belongs afterwards: just past the closing brackets, ready to keep writing.
    ///
    /// A `]]` already sitting after the cursor is swallowed rather than doubled — that happens
    /// when an existing link is being edited.
    public static func completing(_ text: String, draft: Draft, with title: String) -> (text: String, cursor: Int) {
        let ns = text as NSString
        var end = draft.cursor
        if end + 2 <= ns.length, ns.substring(with: NSRange(location: end, length: 2)) == "]]" { end += 2 }
        let replacement = "[[\(title)]]"
        let range = NSRange(location: draft.start, length: end - draft.start)
        let updated = ns.replacingCharacters(in: range, with: replacement)
        return (updated, draft.start + (replacement as NSString).length)
    }

    /// The title of the `[[link]]` the given offset falls inside, or nil. Used for a click.
    public static func link(at offset: Int, in text: String) -> String? {
        let ns = text as NSString
        guard offset >= 0, offset <= ns.length else { return nil }
        for match in matches(in: text) where NSLocationInRange(offset, match.range) || offset == NSMaxRange(match.range) {
            return match.title
        }
        return nil
    }

    /// Every `[[link]]` in the text, with the title inside it.
    public static func matches(in text: String) -> [(range: NSRange, title: String)] {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]\n]+)\]\]"#) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            (range: $0.range, title: ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces))
        }
    }

    /// The titles a note links to, in the order they appear, each named once.
    public static func titles(in text: String) -> [String] {
        var seen = Set<String>()
        return matches(in: text).map(\.title).filter { seen.insert($0.lowercased()).inserted }
    }
}

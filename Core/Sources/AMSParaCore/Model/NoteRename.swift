import Foundation

public extension Note {
    /// The keys whose value names another note, so a rename has to follow them.
    static let referenceKeys = ["goal", "area", "parent", "related"]

    /// This note with its own `# Heading` renamed, when the heading still said the old title.
    /// Only the first heading is touched; headings further down are the note's own structure.
    func headingRenamed(from old: String, to new: String) -> Note {
        var lines = body.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }
            let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            if text.caseInsensitiveCompare(old) == .orderedSame {
                lines[index] = "# " + new
            }
            break
        }
        var renamed = self
        renamed.body = lines.joined(separator: "\n")
        return renamed
    }

    /// This note with every reference to `old` pointing at `new`: the frontmatter keys that
    /// name a note, and `[[wikilinks]]` in the text. Nil when it never mentioned the old title,
    /// so a rename only rewrites the files that really had to change.
    func retargeting(_ old: String, to new: String) -> Note? {
        guard old.caseInsensitiveCompare(new) != .orderedSame else { return nil }
        var changed = false
        var updated = self

        for key in Note.referenceKeys {
            let values = frontmatter.list(key)
            guard !values.isEmpty else { continue }
            let rewritten = values.map { value -> String in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                return trimmed.caseInsensitiveCompare(old) == .orderedSame ? new : value
            }
            guard rewritten != values else { continue }
            changed = true
            if rewritten.count == 1 {
                updated.frontmatter.set(key, rewritten[0])
            } else {
                updated.frontmatter.set(key, list: rewritten)
            }
        }

        let rewrittenBody = Note.rewritingWikilinks(in: body, from: old, to: new)
        if rewrittenBody != body {
            changed = true
            updated.body = rewrittenBody
        }
        return changed ? updated : nil
    }

    /// `[[Old]]` and `[[Old|shown as this]]` become `[[New]]` and `[[New|shown as this]]`.
    static func rewritingWikilinks(in text: String, from old: String, to new: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: old)
        let pattern = "\\[\\[\\s*\(escaped)\\s*(\\|[^\\]]*)?\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let replacement = "[[\(NSRegularExpression.escapedTemplate(for: new))$1]]"
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

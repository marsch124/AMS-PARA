import Foundation

/// How a piece of a note should look while it is being edited.
public enum MarkdownStyle: Equatable, Sendable {
    /// A whole heading line; the level sets the size.
    case heading(level: Int)
    /// Syntax that is not content: `#`, `**`, backticks, the `- [ ]` box.
    case marker
    case bold
    case italic
    case code
    /// `[[Another note]]`
    case link
    /// The text of a task that is done or cancelled.
    case finished
    /// `>2026-09-10`, `@done(...)`, `@repeat(...)`
    case dueDate
    /// `!`, `!!`, `!!!`
    case priority
    /// `#tag`
    case tag
    /// A `>` quote line.
    case quote
    /// The `---` block of settings at the top of a note.
    case frontmatter
    /// A `---` line on its own.
    case rule
}

public struct MarkdownSpan: Equatable, Sendable {
    public var range: NSRange
    public var style: MarkdownStyle

    public init(range: NSRange, style: MarkdownStyle) {
        self.range = range
        self.style = style
    }
}

/// Works out how to draw a note in the editor. Block styles come first, inline ones after,
/// so an editor that applies them in order lets the smaller piece win.
public enum MarkdownHighlight {
    static let headingRegex = try! NSRegularExpression(pattern: #"^(#{1,6})(\s+)(.*)$"#)
    static let quoteRegex = try! NSRegularExpression(pattern: #"^(\s*>\s?)(.*)$"#)
    static let ruleRegex = try! NSRegularExpression(pattern: #"^(-{3,}|\*{3,}|_{3,})\s*$"#)
    static let boldRegex = try! NSRegularExpression(pattern: #"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    static let italicRegex = try! NSRegularExpression(pattern: #"(?<![\*_\w])([\*_])(?=\S)([^\*_]+?)(?<=\S)\1(?![\*_\w])"#)
    static let inlineCodeRegex = try! NSRegularExpression(pattern: #"(`+)([^`]+?)\1"#)
    static let wikilinkRegex = try! NSRegularExpression(pattern: #"\[\[[^\]]+\]\]"#)
    static let listBulletRegex = try! NSRegularExpression(pattern: #"^(\s*[-*+]\s)(?!\[)"#)

    /// Everything the editor needs to draw `text`.
    public static func spans(in text: String) -> [MarkdownSpan] {
        let ns = text as NSString
        var spans: [MarkdownSpan] = []
        var inline: [MarkdownSpan] = []
        var plainRanges: [NSRange] = []

        var lineStart = 0
        var index = 0
        var lines: [(range: NSRange, text: String)] = []
        while index <= ns.length {
            if index == ns.length || ns.character(at: index) == 10 {
                let range = NSRange(location: lineStart, length: index - lineStart)
                lines.append((range, ns.substring(with: range)))
                lineStart = index + 1
            }
            index += 1
        }

        // The settings block at the top is one dim block, never styled as markdown.
        var firstBody = 0
        if let first = lines.first, first.text.trimmingCharacters(in: .whitespaces) == "---",
           let closing = lines.dropFirst().firstIndex(where: { $0.text.trimmingCharacters(in: .whitespaces) == "---" }) {
            let end = NSMaxRange(lines[closing].range)
            spans.append(MarkdownSpan(range: NSRange(location: 0, length: end), style: .frontmatter))
            firstBody = closing + 1
        }

        var inFence = false
        for i in firstBody..<lines.count {
            let (range, line) = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                spans.append(MarkdownSpan(range: range, style: .code))
                inFence.toggle()
                continue
            }
            if inFence {
                spans.append(MarkdownSpan(range: range, style: .code))
                continue
            }
            guard range.length > 0 else { continue }
            let lineNS = line as NSString
            let full = NSRange(location: 0, length: lineNS.length)

            if ruleRegex.firstMatch(in: line, range: full) != nil {
                spans.append(MarkdownSpan(range: range, style: .rule))
                continue
            }
            if let m = headingRegex.firstMatch(in: line, range: full) {
                let level = m.range(at: 1).length
                spans.append(MarkdownSpan(range: range, style: .heading(level: level)))
                spans.append(MarkdownSpan(range: shift(m.range(at: 1), by: range.location), style: .marker))
                inline += inlineSpans(in: lineNS.substring(with: m.range(at: 3)),
                                      offset: range.location + m.range(at: 3).location)
                continue
            }
            if let task = TaskParser.parse(line: line) {
                taskSpans(line: lineNS, task: task, lineRange: range, into: &spans, inline: &inline)
                continue
            }
            if let m = quoteRegex.firstMatch(in: line, range: full) {
                spans.append(MarkdownSpan(range: range, style: .quote))
                spans.append(MarkdownSpan(range: shift(m.range(at: 1), by: range.location), style: .marker))
                inline += inlineSpans(in: lineNS.substring(with: m.range(at: 2)),
                                      offset: range.location + m.range(at: 2).location)
                continue
            }
            if let m = listBulletRegex.firstMatch(in: line, range: full) {
                spans.append(MarkdownSpan(range: shift(m.range(at: 1), by: range.location), style: .marker))
            }
            plainRanges.append(range)
            inline += inlineSpans(in: line, offset: range.location)
        }
        _ = plainRanges
        return spans + inline
    }

    /// The parts of a task line: the checkbox, the finished text, and the tokens after it.
    private static func taskSpans(line: NSString, task: TaskItem, lineRange: NSRange,
                                  into spans: inout [MarkdownSpan], inline: inout [MarkdownSpan]) {
        let text = line as String
        let full = NSRange(location: 0, length: line.length)
        if let box = TaskParser.lineRegex.firstMatch(in: text, range: full) {
            let marker = NSRange(location: box.range(at: 2).location,
                                 length: NSMaxRange(box.range(at: 3)) + 1 - box.range(at: 2).location)
            spans.append(MarkdownSpan(range: shift(marker, by: lineRange.location), style: .marker))
            if task.isDone, box.range(at: 4).location != NSNotFound {
                spans.append(MarkdownSpan(range: shift(box.range(at: 4), by: lineRange.location), style: .finished))
            }
        }
        for regex in [TaskParser.dueRegex, TaskParser.doneRegex, TaskParser.repeatRegex] {
            for m in regex.matches(in: text, range: full) {
                spans.append(MarkdownSpan(range: shift(m.range, by: lineRange.location), style: .dueDate))
            }
        }
        for m in TaskParser.priorityRegex.matches(in: text, range: full) {
            spans.append(MarkdownSpan(range: shift(m.range, by: lineRange.location), style: .priority))
        }
        for m in TaskParser.tagRegex.matches(in: text, range: full) {
            spans.append(MarkdownSpan(range: shift(m.range, by: lineRange.location), style: .tag))
        }
        for m in TaskParser.idRegex.matches(in: text, range: full) {
            spans.append(MarkdownSpan(range: shift(m.range, by: lineRange.location), style: .marker))
        }
        inline += inlineSpans(in: text, offset: lineRange.location).filter { $0.style == .link }
    }

    /// Bold, italics, code and wikilinks inside a stretch of text.
    private static func inlineSpans(in text: String, offset: Int) -> [MarkdownSpan] {
        var result: [MarkdownSpan] = []
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        for m in inlineCodeRegex.matches(in: text, range: full) {
            result.append(MarkdownSpan(range: shift(m.range, by: offset), style: .code))
            result.append(MarkdownSpan(range: shift(m.range(at: 1), by: offset), style: .marker))
        }
        for m in boldRegex.matches(in: text, range: full) {
            result.append(MarkdownSpan(range: shift(m.range, by: offset), style: .bold))
            result.append(MarkdownSpan(range: shift(m.range(at: 1), by: offset), style: .marker))
            let closing = NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length, length: m.range(at: 1).length)
            result.append(MarkdownSpan(range: shift(closing, by: offset), style: .marker))
        }
        for m in italicRegex.matches(in: text, range: full) {
            result.append(MarkdownSpan(range: shift(m.range, by: offset), style: .italic))
            result.append(MarkdownSpan(range: shift(m.range(at: 1), by: offset), style: .marker))
            let closing = NSRange(location: NSMaxRange(m.range) - 1, length: 1)
            result.append(MarkdownSpan(range: shift(closing, by: offset), style: .marker))
        }
        for m in wikilinkRegex.matches(in: text, range: full) {
            result.append(MarkdownSpan(range: shift(m.range, by: offset), style: .link))
        }
        return result
    }

    private static func shift(_ range: NSRange, by offset: Int) -> NSRange {
        NSRange(location: range.location + offset, length: range.length)
    }
}

import SwiftUI
import AMSParaCore

/// A light markdown renderer: headings, lists, tasks (toggle in place), quotes, code and inline styles.
/// `[[Wikilinks]]` become tappable and open the linked note.
struct MarkdownPreview: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let beforeToggle: () -> Void

    static let linkScheme = "amspara"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    render(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .textSelection(.enabled)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == Self.linkScheme else { return .systemAction }
            let reference = url.host.flatMap { $0.removingPercentEncoding } ?? ""
            if !reference.isEmpty { model.open(reference: reference) }
            return .handled
        })
    }

    // MARK: Blocks

    enum Block {
        case heading(level: Int, text: String)
        case task(TaskItem)
        case bullet(indent: Int, text: String)
        case numbered(indent: Int, number: String, text: String)
        case quote(String)
        case code([String])
        case rule
        case paragraph(String)
        case blank
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var codeLines: [String]?
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                result.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
        }

        for (i, raw) in note.lines.enumerated() {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if let code = codeLines {
                    result.append(.code(code))
                    codeLines = nil
                } else {
                    flushParagraph()
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines?.append(line)
                continue
            }
            if trimmed.isEmpty {
                flushParagraph()
                result.append(.blank)
                continue
            }
            if let task = TaskParser.parse(line: line, lineIndex: i) {
                flushParagraph()
                result.append(.task(task))
                continue
            }
            let level = Self.headingLevel(trimmed)
            if level > 0 {
                flushParagraph()
                result.append(.heading(level: level, text: String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                result.append(.rule)
                continue
            }
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                flushParagraph()
                result.append(.quote(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                result.append(.bullet(indent: indent, text: String(trimmed.dropFirst(2))))
                continue
            }
            if let dot = trimmed.firstIndex(of: "."), trimmed[..<dot].allSatisfy(\.isNumber), !trimmed[..<dot].isEmpty,
               trimmed.index(after: dot) < trimmed.endIndex, trimmed[trimmed.index(after: dot)] == " " {
                flushParagraph()
                result.append(.numbered(indent: indent, number: String(trimmed[..<dot]),
                                        text: String(trimmed[trimmed.index(dot, offsetBy: 2)...])))
                continue
            }
            paragraph.append(trimmed)
        }
        if let code = codeLines { result.append(.code(code)) }
        flushParagraph()
        return result
    }

    private static func headingLevel(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 } else { break }
        }
        guard count > 0, count <= 6, line.dropFirst(count).first == " " else { return 0 }
        return count
    }

    // MARK: Rendering

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 8 : 4)
        case .task(let task):
            TaskRow(ref: TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task), showNote: false) {
                beforeToggle()
                model.toggle(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task))
            }
            .padding(.leading, CGFloat(task.indent.count) * 8)
        case .bullet(let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 8)
        case .numbered(let indent, let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 8)
        case .quote(let text):
            HStack(spacing: 8) {
                Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 3)
                inline(text).foregroundStyle(.secondary)
            }
        case .code(let lines):
            Text(lines.joined(separator: "\n"))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        case .rule:
            Divider()
        case .paragraph(let text):
            inline(text)
        case .blank:
            Spacer().frame(height: 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        case 3: return .title3.bold()
        default: return .headline
        }
    }

    /// Inline markdown with wikilinks turned into `amspara://` links.
    private func inline(_ text: String) -> Text {
        let converted = Self.convertWikilinks(text)
        if let attributed = try? AttributedString(markdown: converted, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(text)
    }

    static let wikilinkRegex = try! NSRegularExpression(pattern: #"\[\[([^\]\|#]+)(?:#[^\]\|]*)?(?:\|([^\]]*))?\]\]"#)

    static func convertWikilinks(_ text: String) -> String {
        let ns = text as NSString
        var out = ns
        for m in wikilinkRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let target = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let alias = m.range(at: 2).location == NSNotFound ? target : ns.substring(with: m.range(at: 2))
            let encoded = target.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? target
            out = out.replacingCharacters(in: m.range, with: "[\(alias)](\(linkScheme)://\(encoded))") as NSString
        }
        return out as String
    }
}

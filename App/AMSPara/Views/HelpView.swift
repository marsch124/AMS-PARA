import SwiftUI

/// The built-in manual: "How it works" and the version history, both markdown files in the
/// app bundle (`Docs/`). Rendered with a small renderer that knows headings, bullets,
/// paragraphs and fenced code, which is all the documents use.
struct HelpView: View {
    enum Page: String, CaseIterable, Identifiable, Codable, Hashable {
        case howItWorks = "How it works"
        case versionHistory = "Version history"

        var id: String { rawValue }

        var fileName: String {
            switch self {
            case .howItWorks: return "HowItWorks"
            case .versionHistory: return "VersionHistory"
            }
        }
    }

    @State var page: Page = .howItWorks

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            HelpDocument(fileName: page.fileName)
                .id(page)
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}

/// One markdown document from the bundle.
struct HelpDocument: View {
    let fileName: String

    private var blocks: [HelpBlock] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [.paragraph("The document \(fileName).md is missing from this build.")]
        }
        return HelpBlock.parse(text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    render(block)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(20)
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func render(_ block: HelpBlock) -> some View {
        switch block {
        case .title(let text):
            Text(text).font(.title.bold()).padding(.bottom, 4)
        case .heading(let text):
            Text(text).font(.title3.weight(.semibold)).padding(.top, 10)
        case .paragraph(let text):
            Text(Self.inline(text))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(Self.inline(item))
                    }
                }
            }
            .padding(.leading, 4)
        case .code(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Bold, italics and `code` inside a line.
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

enum HelpBlock {
    case title(String)
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case code(String)

    static func parse(_ text: String) -> [HelpBlock] {
        var blocks: [HelpBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var code: [String]?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let open = code {
                if line.hasPrefix("```") { blocks.append(.code(open.joined(separator: "\n"))); code = nil }
                else { code?.append(rawLine) }
                continue
            }
            if line.hasPrefix("```") { flush(); code = []; continue }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("# ") { flush(); blocks.append(.title(String(line.dropFirst(2)))); continue }
            if line.hasPrefix("## ") { flush(); blocks.append(.heading(String(line.dropFirst(3)))); continue }
            if line.hasPrefix("- ") {
                if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
                bullets.append(String(line.dropFirst(2)))
                continue
            }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            paragraph.append(line)
        }
        if let open = code { blocks.append(.code(open.joined(separator: "\n"))) }
        flush()
        return blocks
    }
}

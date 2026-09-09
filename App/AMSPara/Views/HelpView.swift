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

/// One markdown document from the bundle, as a title and a list of sections you can open
/// one at a time. A manual you scroll is a manual you do not read; this one is a contents
/// page you drill into, with a search box that filters it.
struct HelpDocument: View {
    let fileName: String
    @State private var open: Set<String> = []
    @State private var search = ""

    private var document: HelpParts {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return HelpParts(title: fileName,
                             intro: [.paragraph("The document \(fileName).md is missing from this build.")],
                             sections: [])
        }
        return HelpParts(text: text)
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var sections: [HelpSection] {
        guard !query.isEmpty else { return document.sections }
        return document.sections.filter { $0.matches(query) }
    }

    /// While searching, everything that matched is open: the answer should be on screen,
    /// not behind another click.
    private func isOpen(_ section: HelpSection) -> Bool {
        !query.isEmpty || open.contains(section.id)
    }

    private func binding(for section: HelpSection) -> Binding<Bool> {
        Binding(get: { isOpen(section) },
                set: { wanted in
                    if wanted { open.insert(section.id) } else { open.remove(section.id) }
                })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(document.title)
                    .font(.title.bold())
                ForEach(Array(document.intro.enumerated()), id: \.offset) { _, block in
                    render(block)
                }
                if sections.isEmpty {
                    Text("Nothing in this page matches \u{201C}\(query)\u{201D}.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                ForEach(sections) { section in
                    DisclosureGroup(isExpanded: binding(for: section)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                                render(block)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.leading, 2)
                    } label: {
                        Text(section.title)
                            .font(.title3.weight(.semibold))
                    }
                    Divider()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(20)
            .textSelection(.enabled)
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search this page", text: $search)
                    .textFieldStyle(.roundedBorder)
                if !query.isEmpty {
                    Button("Clear") { search = "" }
                        .buttonStyle(.borderless)
                }
                Button(open.isEmpty ? "Open all" : "Close all") {
                    open = open.isEmpty ? Set(document.sections.map(\.id)) : []
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func render(_ block: HelpBlock) -> some View {
        switch block {
        case .title(let text):
            Text(text).font(.title.bold()).padding(.bottom, 4)
        case .heading(let text):
            Text(text).font(.title3.weight(.semibold)).padding(.top, 10)
        case .subheading(let text):
            Text(text).font(.headline).padding(.top, 8)
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
    case subheading(String)
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
            if line.hasPrefix("### ") { flush(); blocks.append(.subheading(String(line.dropFirst(4)))); continue }
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

/// One `##` section of a help document: its heading and everything under it.
struct HelpSection: Identifiable {
    let title: String
    let blocks: [HelpBlock]

    var id: String { title }

    /// True when the heading or any line inside mentions what was typed.
    func matches(_ query: String) -> Bool {
        if title.localizedCaseInsensitiveContains(query) { return true }
        return blocks.contains { $0.text.localizedCaseInsensitiveContains(query) }
    }
}

/// A help document split into its title, whatever comes before the first heading, and
/// the sections themselves.
struct HelpParts {
    let title: String
    let intro: [HelpBlock]
    let sections: [HelpSection]

    init(title: String, intro: [HelpBlock], sections: [HelpSection]) {
        self.title = title
        self.intro = intro
        self.sections = sections
    }

    init(text: String) {
        var title = ""
        var intro: [HelpBlock] = []
        var sections: [HelpSection] = []
        var heading: String?
        var blocks: [HelpBlock] = []

        func close() {
            if let heading {
                sections.append(HelpSection(title: heading, blocks: blocks))
            } else {
                intro = blocks
            }
            blocks = []
        }

        for block in HelpBlock.parse(text) {
            switch block {
            case .title(let text):
                if title.isEmpty { title = text } else { blocks.append(block) }
            case .heading(let text):
                close()
                heading = text
            default:
                blocks.append(block)
            }
        }
        close()

        self.title = title
        self.intro = intro
        self.sections = sections
    }
}

extension HelpBlock {
    /// The words in this block, for searching.
    var text: String {
        switch self {
        case .title(let text), .heading(let text), .subheading(let text),
             .paragraph(let text), .code(let text):
            return text
        case .bullets(let items):
            return items.joined(separator: "\n")
        }
    }
}

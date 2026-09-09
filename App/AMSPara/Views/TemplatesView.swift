import SwiftUI
import AMSParaCore

/// The Templates section: the files a new note is made from, and the snippets you can drop
/// into one. They are ordinary markdown in the vault's `Templates` folder; this is a way to
/// edit them without leaving the app.
struct TemplatesView: View {
    @EnvironmentObject private var model: AppModel

    private var names: [String] { model.templateNames }

    var body: some View {
        Group {
            if names.isEmpty {
                EmptyStateView(title: "No templates",
                               systemImage: SidebarSection.templates.systemImage,
                               message: "They live in the Templates folder inside your vault. Open a vault to see them.")
            } else {
                List(selection: $model.templateSelection) {
                    Section("A new note starts from") {
                        ForEach(names.filter { $0 != Snippets.fileName }, id: \.self) { name in
                            TemplateRow(name: name, detail: Self.explains[name] ?? "Template")
                                .tag(name)
                        }
                    }
                    if names.contains(Snippets.fileName) {
                        Section("Blocks you can drop into a note") {
                            TemplateRow(name: Snippets.fileName,
                                        detail: model.snippets.isEmpty ? "None yet"
                                              : model.snippets.map(\.name).joined(separator: ", "))
                                .tag(Snippets.fileName)
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .onAppear { if model.templateSelection == nil { model.templateSelection = names.first } }
    }

    /// One line saying what each template is for, so the list explains itself.
    static let explains: [String: String] = [
        "Project": "Outcome, tasks, notes, log",
        "Area": "The standard to keep, tasks, notes",
        "Resource": "Reference material",
        "Goal": "Horizon, measure, what serves it",
        "Daily": "The day's note",
        "Weekly": "The week's plan",
    ]
}

struct TemplateRow: View {
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: name == Snippets.fileName ? ParaKind.project.tint : ParaKind.resource.tint, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The detail column while Templates is open: the file itself, in a plain editor.
struct TemplateEditorView: View {
    @EnvironmentObject private var model: AppModel
    let name: String
    @State private var text = ""
    @State private var loaded = ""

    private var isDirty: Bool { text != loaded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(6)
        }
        .navigationTitle(name)
        .toolbar {
            ToolbarItem {
                Button("Save") { save() }
                    .disabled(!isDirty)
                    .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .onAppear(perform: load)
        .onChange(of: name) { _, _ in load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(explanation)
                .font(.callout)
            Text("`{{title}}` becomes the note's name and `{{date}}` today's date. In snippets, `{{tomorrow}}` and `{{week}}` work too, and anything else in braces is asked for when you use it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var explanation: String {
        name == Snippets.fileName
            ? "Each ## heading is a snippet. Its lines are added to a note's Tasks when you pick it from Add a task."
            : "Every new \(name.lowercased()) note starts as a copy of this."
    }

    private func load() {
        loaded = model.templateText(named: name)
        text = loaded
    }

    private func save() {
        model.saveTemplate(named: name, text: text)
        loaded = text
    }
}

/// Asks for the words a snippet leaves open, then hands them back.
struct SnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snippet: Snippet
    let insert: ([String: String]) -> Void
    @State private var answers: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(snippet.name)
                .font(.title2.bold())
            Text("Fill these in and the block is added to the note's tasks. Dates are worked out for you.")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(snippet.questions, id: \.self) { question in
                VStack(alignment: .leading, spacing: 3) {
                    Text(question.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(question, text: binding(for: question))
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    insert(answers)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func binding(for question: String) -> Binding<String> {
        Binding(get: { answers[question] ?? "" }, set: { answers[question] = $0 })
    }
}

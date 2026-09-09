import SwiftUI
import AMSParaCore

/// The Templates section: the files a new note is made from, and the snippets you can drop
/// into one. They are ordinary markdown in the vault's `Templates` folder; this is a way to
/// edit them without leaving the app.
struct TemplatesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var folded: Set<String> = []
    @State private var making = false
    @State private var newName = ""
    @State private var newKind: ParaKind = .project
    @State private var renaming: String?
    @State private var renameDraft = ""
    @State private var deleting: String?

    /// The templates gathered under the kind of note they make, in the app's own order,
    /// with anything that does not say what it makes at the end.
    private var groups: [TemplateGroup] {
        let kinds: [ParaKind] = [.goal, .project, .area, .resource, .archive, .daily]
        var groups = kinds.compactMap { kind -> TemplateGroup? in
            let files = model.templates.filter { $0.kind == kind }
                .sorted { a, b in a.isDefault == b.isDefault ? a.name < b.name : a.isDefault }
            return files.isEmpty ? nil : TemplateGroup(title: kind.displayName, tint: kind.tint, files: files)
        }
        let rest = model.templates.filter { $0.kind == nil && !$0.isSnippets }
        if !rest.isEmpty {
            groups.append(TemplateGroup(title: "Other", tint: .secondary, files: rest))
        }
        if let snippets = model.templates.first(where: \.isSnippets) {
            groups.append(TemplateGroup(title: "Snippets", tint: SidebarSection.inbox.tint, files: [snippets]))
        }
        return groups
    }

    var body: some View {
        Group {
            if model.templates.isEmpty {
                EmptyStateView(title: "No templates",
                               systemImage: SidebarSection.templates.systemImage,
                               message: "They live in the Templates folder inside your vault. Open a vault to see them.")
            } else {
                // Plain sections with a fold button in the header. DisclosureGroups inside a
                // List drew their rows on top of each other (build 90).
                List(selection: $model.templateSelection) {
                    ForEach(groups) { group in
                        Section {
                            if !folded.contains(group.title) {
                                ForEach(group.files) { file in
                                    TemplateRow(file: file, tint: group.tint, detail: detail(for: file))
                                        .tag(file.name)
                                        .contextMenu {
                                            Button("Rename\u{2026}") {
                                                renameDraft = file.name
                                                renaming = file.name
                                            }
                                            Button("Delete\u{2026}", role: .destructive) { deleting = file.name }
                                        }
                                }
                            }
                        } header: {
                            Button {
                                toggleFold(group.title)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: folded.contains(group.title) ? "chevron.right" : "chevron.down")
                                        .font(.caption2)
                                    Text(group.title.uppercased())
                                        .font(.caption.weight(.semibold))
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(group.tint)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem {
                Button {
                    newName = ""
                    making = true
                } label: {
                    Label("New template", systemImage: "plus")
                }
                .help("Add another template, so a kind of note can start in more than one way")
            }
        }
        .sheet(isPresented: $making) {
            NewTemplateSheet(name: $newName, kind: $newKind) {
                model.createTemplate(named: newName, kind: newKind)
            }
        }
        .alert("Rename \u{201C}\(renaming ?? "")\u{201D}",
               isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameDraft)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") {
                if let renaming { model.renameTemplate(named: renaming, to: renameDraft) }
                renaming = nil
            }
        }
        .confirmationDialog("Delete the \u{201C}\(deleting ?? "")\u{201D} template?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let deleting { model.deleteTemplate(named: deleting) }
                deleting = nil
            }
        } message: {
            Text("Only the template goes; notes already made from it are untouched. Delete the one a kind uses by default and new notes get a bare note instead.")
        }
        #if os(macOS)
        .onAppear { if model.templateSelection == nil { model.templateSelection = model.templates.first?.name } }
        #endif
    }

    private func toggleFold(_ title: String) {
        if folded.contains(title) { folded.remove(title) } else { folded.insert(title) }
    }

    private func detail(for file: TemplateFile) -> String {
        if file.isSnippets {
            return model.snippets.isEmpty ? "None yet" : model.snippets.map(\.name).joined(separator: ", ")
        }
        if let explained = Self.explains[file.name] {
            return file.isDefault ? "Used by default \u{00B7} \(explained)" : explained
        }
        return file.isDefault ? "Used by default" : "One way to start"
    }

    /// One line saying what each template the app ships with is for.
    static let explains: [String: String] = [
        "Project": "Outcome, tasks, notes, log",
        "Area": "The standard to keep, tasks, notes",
        "Resource": "Reference material",
        "Goal": "Horizon, measure, what serves it",
        "Daily": "The day's note",
        "Weekly": "The week's plan",
    ]
}

struct TemplateGroup: Identifiable {
    let title: String
    let tint: Color
    let files: [TemplateFile]

    var id: String { title }
}

struct TemplateRow: View {
    let file: TemplateFile
    let tint: Color
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: tint, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.headline)
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
    @State private var pending: Task<Void, Never>?

    private var isDirty: Bool { text != loaded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            // The same editor the notes use. A plain SwiftUI TextEditor showed the file here
            // but would not take a keystroke (build 90); this one is proven in the note
            // screen, in this very column, and colours the markdown as a bonus.
            MarkdownSyntaxEditor(text: $text, tint: ParaKind.resource.tint)
        }
        .navigationTitle(name)
        .toolbar {
            ToolbarItem {
                // "Saved" rather than a greyed-out Save: the file is written a moment after
                // you stop typing, and a dimmed button looked like nothing had happened.
                if isDirty {
                    Button("Save") { save() }
                        .keyboardShortcut("s", modifiers: [.command])
                } else {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: name) { _, _ in
            saveIfNeeded()
            load()
        }
        // Typing is saved a moment after you stop, the way a note is, so the Save button is
        // a reassurance rather than something you must remember.
        .onChange(of: text) { _, _ in scheduleSave() }
        .onDisappear { saveIfNeeded() }
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
        if name == Snippets.fileName {
            return "Each ## heading is a snippet. Its lines are added to a note's Tasks when you pick it from Add a task."
        }
        guard let file = model.templates.first(where: { $0.name == name }), let kind = file.kind else {
            return "A template. It is used when a note is made from it."
        }
        if file.isDefault {
            return "Every new \(kind.displayName.lowercased()) note starts as a copy of this."
        }
        return "One way to start a \(kind.displayName.lowercased()) note. Pick it under New note \u{203A} Start from."
    }

    private func load() {
        loaded = model.templateText(named: name)
        text = loaded
    }

    private func save(announce: Bool = true) {
        pending?.cancel()
        pending = nil
        model.saveTemplate(named: name, text: text, announce: announce)
        loaded = text
    }

    private func saveIfNeeded() {
        guard isDirty else { return }
        save(announce: false)
    }

    private func scheduleSave() {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            saveIfNeeded()
        }
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

/// Naming a new template and saying what it makes. A sheet rather than an alert: a macOS
/// alert quietly drops anything that is not a text field, so the "makes a" picker vanished
/// and every new template came out a project (build 90).
struct NewTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var kind: ParaKind
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New template")
                .font(.title2.bold())
            Text("A template is how a note starts. You can have as many as you like for the same kind of note — a plain project and a client project, say — and pick between them when you make one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Client project", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Makes a").font(.caption).foregroundStyle(.secondary)
                Picker("Makes a", selection: $kind) {
                    ForEach([ParaKind.goal, .project, .area, .resource], id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Text("It starts as a copy of the \(kind.displayName.lowercased()) template you use now. Change it afterwards to whatever you want.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    create()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

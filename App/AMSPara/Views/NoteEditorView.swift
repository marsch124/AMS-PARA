import SwiftUI
import AMSParaCore

struct NoteEditorView: View {
    @EnvironmentObject private var model: AppModel
    let path: String

    @State private var text = ""
    @State private var newTask = ""
    @State private var isDirty = false
    @State private var pendingSave: Task<Void, Never>?
    @State private var showTasks = true
    @State private var showLinks = false

    private var note: Note? { model.note(at: path) }
    private var storedText: String { note?.text ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            if let note {
                NoteHeader(note: note)
                Divider()
                if !note.tasks.isEmpty {
                    DisclosureGroup(isExpanded: $showTasks) {
                        TaskChecklist(note: note, beforeToggle: flushSave)
                    } label: {
                        Text("Tasks (\(note.openTasks.count) open)")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
                let linked = linkedNotes(for: note)
                if !linked.isEmpty {
                    DisclosureGroup(isExpanded: $showLinks) {
                        LinkedNotesList(notes: linked)
                    } label: {
                        Text("Linked notes (\(linked.count))")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .onChange(of: text) { _, newValue in
                    scheduleSave(newValue)
                }
            Divider()
            HStack {
                TextField("Add a task… (use >2026-09-10 for a date, !! for priority, #tag)", text: $newTask)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTask)
                Button("Add", action: addTask)
                    .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
        .onAppear { text = storedText }
        .onDisappear { flushSave() }
        .onChange(of: storedText) { _, newValue in
            if !isDirty && newValue != text { text = newValue }
        }
        .navigationTitle(note?.title ?? path)
        .toolbar {
            ToolbarItemGroup {
                if let note, note.kind == .project || note.kind == .area || note.kind == .resource {
                    Button {
                        flushSave()
                        model.archive(note)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .help("Move this note to the Archive folder and stop syncing its tasks")
                }
            }
        }
    }

    private func linkedNotes(for note: Note) -> [Note] {
        let index = model.index
        var seen = Set<String>()
        var result: [Note] = []
        for candidate in index.backlinks(to: note) + note.outgoingReferences.compactMap(index.note(matching:)) {
            guard candidate.relativePath != note.relativePath, seen.insert(candidate.relativePath).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    private func scheduleSave(_ newValue: String) {
        guard newValue != storedText else {
            isDirty = false
            return
        }
        isDirty = true
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            model.saveText(newValue, forNoteAt: path)
            isDirty = false
        }
    }

    private func flushSave() {
        pendingSave?.cancel()
        pendingSave = nil
        if isDirty {
            model.saveText(text, forNoteAt: path)
            isDirty = false
        }
    }

    private func addTask() {
        flushSave()
        model.addTask(newTask, to: path)
        newTask = ""
    }
}

struct NoteHeader: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            Label(note.kind.displayName, systemImage: SidebarSection.kind(note.kind).systemImage)
            if let status = note.status {
                Label(status.capitalized, systemImage: "circle.fill")
            }
            if let area = note.area {
                Label(area, systemImage: "circle.grid.2x2")
            }
            if let due = note.dueDate {
                Label("Due \(due.description)", systemImage: "calendar")
            }
            if !note.tags.isEmpty {
                Label(note.tags.map { "#\($0)" }.joined(separator: " "), systemImage: "number")
            }
            Spacer()
            if note.kind.isTaskKind {
                Label(note.isSyncEnabled && !note.isArchived ? "List: \(note.kind == .inbox ? "Inbox" : note.remindersListName)" : "Not synced",
                      systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct TaskChecklist: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let beforeToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(note.tasks, id: \.lineIndex) { task in
                TaskRow(ref: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task), showNote: false) {
                    beforeToggle()
                    model.toggle(TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task))
                }
            }
        }
        .padding(.top, 4)
    }
}

struct TaskRow: View {
    let ref: TaskRef
    let showNote: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: toggle) {
                Image(systemName: ref.task.status == .cancelled ? "xmark.circle" : (ref.task.isDone ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(ref.task.isDone ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(ref.task.title)
                    .strikethrough(ref.task.isDone)
                    .foregroundStyle(ref.task.isDone ? .secondary : .primary)
                HStack(spacing: 8) {
                    if ref.task.priority > 0 {
                        Text(String(repeating: "!", count: ref.task.priority))
                            .foregroundStyle(.orange)
                    }
                    if let due = ref.task.dueDate {
                        Label(due.description, systemImage: "calendar")
                            .foregroundStyle(due < .today() && !ref.task.isDone ? Color.red : Color.secondary)
                    }
                    if showNote {
                        Label(ref.noteTitle, systemImage: "doc.text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct LinkedNotesList: View {
    @EnvironmentObject private var model: AppModel
    let notes: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(notes) { linked in
                Button {
                    model.section = linked.kind == .inbox ? .inbox : .kind(linked.kind)
                    model.selectedNotePath = linked.relativePath
                } label: {
                    Label(linked.title, systemImage: SidebarSection.kind(linked.kind).systemImage)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

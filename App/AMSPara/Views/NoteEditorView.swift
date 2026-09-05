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
    @AppStorage("editorMode") private var mode: EditorMode = .edit

    enum EditorMode: String, CaseIterable, Identifiable {
        case edit, split, preview
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private var note: Note? { model.note(at: path) }
    private var storedText: String { note?.text ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            if let note {
                NoteHeader(note: note)
                Divider()
                if let date = note.dailyDate {
                    DayAgendaView(date: date)
                    Divider()
                }
                if let week = note.weekRef {
                    WeekAgendaView(week: week)
                    Divider()
                }
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
            HStack(spacing: 0) {
                if mode != .preview {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .onChange(of: text) { _, newValue in
                            scheduleSave(newValue)
                        }
                }
                if mode == .split {
                    Divider()
                }
                if mode != .edit, let note {
                    MarkdownPreview(note: note, beforeToggle: flushSave)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                TextField("Add a task… (>2026-09-10 or >2026-09-10T14:30 for a date, !! for priority, #tag)", text: $newTask)
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
                Picker("Mode", selection: $mode) {
                    ForEach(EditorMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .help("Edit the markdown, see it rendered, or both")
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
    @EnvironmentObject private var model: AppModel
    let note: Note

    private func listName(for note: Note) -> String {
        switch note.kind {
        case .inbox: return model.config.inboxListName
        case .daily: return model.config.dailyNotesListName
        default: return note.remindersListName
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(note.kind == .daily ? "Daily note" : note.kind.displayName, systemImage: SidebarSection.kind(note.kind).systemImage)
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
                Label(note.isSyncEnabled && !note.isArchived ? "List: \(listName(for: note))" : "Not synced",
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
    @State private var subtaskParent: TaskItem?
    @State private var subtaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(note.tasks, id: \.lineIndex) { task in
                TaskRow(ref: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task), showNote: false) {
                    beforeToggle()
                    model.toggle(TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task))
                }
                .padding(.leading, CGFloat(task.indentLevel) * 14)
                .contextMenu {
                    Button("Add subtask…") {
                        subtaskTitle = ""
                        subtaskParent = task
                    }
                }
            }
        }
        .padding(.top, 4)
        .alert("New subtask", isPresented: Binding(get: { subtaskParent != nil }, set: { if !$0 { subtaskParent = nil } })) {
            TextField("Subtask", text: $subtaskTitle)
            Button("Add") {
                if let parent = subtaskParent {
                    beforeToggle()
                    model.addSubtask(subtaskTitle, to: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: parent))
                }
                subtaskParent = nil
            }
            Button("Cancel", role: .cancel) { subtaskParent = nil }
        } message: {
            Text(subtaskParent.map { "Under \"\($0.title)\". It syncs to Reminders as \"\($0.title) › …\"." } ?? "")
        }
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
                        Label(due.description + (ref.task.dueTime.map { " \($0)" } ?? ""),
                              systemImage: ref.task.dueTime == nil ? "calendar" : "clock")
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
                    model.section = model.sidebarSection(for: linked)
                    model.selectedNotePath = linked.relativePath
                } label: {
                    Label(linked.displayTitle, systemImage: SidebarSection.kind(linked.kind).systemImage)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// Tasks from the whole vault that are due on the day of a daily note.
struct DayAgendaView: View {
    @EnvironmentObject private var model: AppModel
    let date: DateOnly

    var body: some View {
        let refs = model.index.openTasks(dueOn: date).filter { $0.notePath != model.selectedNotePath }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Due on this day")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    model.openDailyNote(for: date.adding(days: -1))
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button("Today") { model.openDailyNote(for: .today()) }
                Button {
                    model.openDailyNote(for: date.adding(days: 1))
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderless)
            if refs.isEmpty {
                Text("Nothing from other notes is due on this day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(refs) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// Tasks due during the week of a weekly note, grouped by day.
struct WeekAgendaView: View {
    @EnvironmentObject private var model: AppModel
    let week: WeekRef
    @State private var expanded = true

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE d")
        return f
    }()

    var body: some View {
        let overview = model.index.weekOverview(for: week)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Due this week (\(overview.dueCount))")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button { model.openWeeklyNote(for: week.adding(weeks: -1)) } label: { Image(systemName: "chevron.left") }
                Button("This week") { model.openWeeklyNote(for: .current()) }
                Button { model.openWeeklyNote(for: week.adding(weeks: 1)) } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.borderless)
            ForEach(overview.days.filter { !$0.due.isEmpty }) { day in
                Text(day.date.date().map(Self.dayFormatter.string(from:)) ?? day.date.description)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                ForEach(day.due) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                }
            }
            if overview.dueCount == 0 {
                Text("Nothing is due this week yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

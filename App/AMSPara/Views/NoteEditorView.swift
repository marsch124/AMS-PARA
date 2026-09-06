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
    @State private var confirmTrash = false
    @State private var vaultPath: String?
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
                if note.kind == .goal {
                    GoalDashboardView(goal: note)
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
            // The editor takes whatever height is left and never asks for more. Without this
            // guard, expanding a disclosure above it made the text editor report its full
            // text height as a minimum, and the window's content grew past the window.
            GeometryReader { geo in
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
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
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
        .onAppear {
            text = storedText
            vaultPath = model.vaultPath
            model.flushEditor = flushSave
        }
        .onDisappear {
            model.flushEditor = nil
            // Runs while SwiftUI is swapping views; save after the update, not inside it.
            pendingSave?.cancel()
            pendingSave = nil
            if isDirty {
                let unsaved = text
                let openedIn = vaultPath
                isDirty = false
                model.afterUpdate {
                    // Only into the vault the note was opened from.
                    if model.vaultPath == openedIn { model.saveText(unsaved, forNoteAt: path) }
                }
            }
        }
        .onChange(of: storedText) { _, newValue in
            if !isDirty && newValue != text { text = newValue }
        }
        .confirmationDialog("Move \u{201C}\(note?.displayTitle ?? "")\u{201D} to the Trash?", isPresented: $confirmTrash) {
            Button("Move to Trash", role: .destructive) {
                guard let note else { return }
                pendingSave?.cancel()
                pendingSave = nil
                isDirty = false
                model.trash(note)
            }
        } message: {
            Text("You can put it back from the Trash in Finder.")
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
                if let note, model.canArchive(note) {
                    Button {
                        flushSave()
                        model.archive(note)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .help("Move this note to the Archive folder and stop syncing its tasks")
                }
                if let note, note.kind != .inbox {
                    Button {
                        confirmTrash = true
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .help("Move this note's file to the Trash (⌘⌫)")
                    .keyboardShortcut(.delete, modifiers: [.command])
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
                .foregroundStyle(note.tint)
                .fontWeight(.semibold)
            if let status = note.status {
                Label(status.capitalized, systemImage: "circle.fill")
            }
            if let area = note.area {
                Label(area, systemImage: "circle.grid.2x2")
                    .foregroundStyle(ParaKind.area.tint)
            }
            if let goal = note.goal {
                Label(goal, systemImage: "star")
                    .foregroundStyle(ParaKind.goal.tint)
                    .contentShape(Rectangle())
                    .onTapGesture { model.openGoal(reference: goal) }
            }
            if let horizon = note.horizon {
                Label(horizon.label, systemImage: "scope")
            }
            if let target = note.targetDate {
                Label("Target \(target.description)", systemImage: "flag.checkered")
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
        .background(note.tint.opacity(0.10))
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
                TaskRow(ref: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task), showNote: false,
                        onAddSubtask: { subtaskTitle = ""; subtaskParent = task }) {
                    beforeToggle()
                    model.toggle(TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task))
                }
                .padding(.leading, CGFloat(task.indentLevel) * 14)
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
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let showNote: Bool
    var onAddSubtask: (() -> Void)? = nil
    let toggle: () -> Void
    @State private var pickingDate = false

    /// Tasks take the colour of the note they live in.
    private var tint: Color {
        model.note(at: ref.notePath)?.tint ?? .accentColor
    }

    private var isNext: Bool { ref.task.tags.contains(Note.nextActionTag) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: toggle) {
                Image(systemName: ref.task.status == .cancelled ? "xmark.circle" : (ref.task.isDone ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(ref.task.isDone ? Color.secondary : tint)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isNext ? Note.removingTag(Note.nextActionTag, from: ref.task.title) : ref.task.title)
                        .strikethrough(ref.task.isDone)
                        .foregroundStyle(ref.task.isDone ? .secondary : .primary)
                    if isNext && !ref.task.isDone {
                        Text("next")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(tint.opacity(0.2), in: Capsule())
                            .foregroundStyle(tint)
                    }
                }
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
                    if let rule = ref.task.repeatRule {
                        Label(rule.label, systemImage: "repeat")
                    }
                    if showNote {
                        Label(ref.noteTitle, systemImage: "doc.text")
                            .foregroundStyle(tint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .draggable(TaskTransfer(ref))
        .contextMenu {
            TaskContextMenu(ref: ref, showNote: showNote, pickingDate: $pickingDate, onAddSubtask: onAddSubtask)
        }
        .popover(isPresented: $pickingDate) {
            TaskDatePicker(ref: ref, isPresented: $pickingDate)
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
                    model.show(linked)
                } label: {
                    HStack(spacing: 8) {
                        KindBadge(kind: linked.kind, size: 18)
                        Text(linked.displayTitle)
                    }
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
            if model.showsCalendarEvents {
                CalendarEventRows(date: date)
            }
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
        .task(id: date) { await model.loadEvents(for: date) }
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
            Text("Drag a task onto a day to plan it there. Tick it here when it is done.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            ForEach(overview.days) { day in
                HStack {
                    Text(day.date.date().map(Self.dayFormatter.string(from:)) ?? day.date.description)
                        .font(.caption.weight(day.date == .today() ? .bold : .semibold))
                    Spacer()
                    if !day.due.isEmpty {
                        Text("\(day.due.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !day.completed.isEmpty {
                        Text("✓ \(day.completed.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(day.date == .today() ? ParaKind.daily.tint : .secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .acceptsTaskDrop { ref in model.setDueDate(ref, day.date) }
                ForEach(day.due + day.undated) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                        .padding(.leading, 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// What serves a goal and whether it is moving: linked projects and areas, rolled-up tasks, recent completions.
struct GoalDashboardView: View {
    @EnvironmentObject private var model: AppModel
    let goal: Note

    var body: some View {
        let health = model.index.goalHealth(of: goal, today: .today())
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                stat("\(health.projects.count)", "projects")
                stat("\(health.areas.count)", "areas")
                stat("\(health.openTaskCount)", "open tasks")
                stat("\(health.completedLast30Days)", "done in 30 days")
                if let days = health.daysSinceActivity {
                    stat(days == 0 ? "today" : "\(days)d", "last activity")
                }
                Spacer()
            }
            if !health.flags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .achieved ? goal.tint.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .achieved ? goal.tint : Color.orange)
                    }
                }
            }
            if let measure = goal.measure {
                Text("Measure: \(measure)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let serving = health.subgoals + health.projects + health.areas
            if serving.isEmpty {
                Text("Nothing serves this goal yet. Add `goal: \(goal.title)` to a project or area's frontmatter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(serving) { note in
                    Button {
                        model.show(note)
                    } label: {
                        HStack(spacing: 8) {
                            KindBadge(kind: note.kind, size: 18)
                            Text(note.title)
                            Spacer()
                            let open = note.openTasks.count
                            if open > 0 {
                                Text("\(open) open")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.headline).foregroundStyle(goal.tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

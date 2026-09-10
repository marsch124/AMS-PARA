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
    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false
    @State private var showLinks = false
    @State private var confirmTrash = false
    @State private var snippetToFill: Snippet?
    @State private var renamingNote = false
    @State private var noteTitleDraft = ""
    /// A `[[` being typed, with where the caret is; nil when nothing is.
    @State private var linkDraft: LinkDraftOnScreen?
    /// The title to write in, handed to the editor.
    @State private var linkCompletion: LinkCompletion?
    /// Which suggestion the arrow keys are on.
    @State private var linkChoice = 0
    @State private var vaultPath: String?
    /// The note's real text (markers included) that the shown text was made from.
    @State private var baseText = ""
    @AppStorage("editorMode") private var mode: EditorMode = .edit
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    enum EditorMode: String, CaseIterable, Identifiable {
        case edit, split, preview
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private var note: Note? { model.note(at: path) }
    private var storedText: String { note?.text ?? "" }
    /// What the editor shows: the note's text with the `^t` sync markers hidden.
    private var displayText: String { TaskIDMasking.hidden(in: storedText) }

    var body: some View {
        Group {
            if isPhone { phoneBody } else { deskBody }
        }
        .onAppear {
            baseText = storedText
            text = displayText
            vaultPath = model.vaultPath
            model.flushEditor = flushSave
        }
        .onDisappear {
            model.flushEditor = nil
            // Runs while SwiftUI is swapping views; save after the update, not inside it.
            pendingSave?.cancel()
            pendingSave = nil
            if isDirty {
                let unsaved = TaskIDMasking.restored(text, from: baseText)
                let openedIn = vaultPath
                isDirty = false
                model.afterUpdate {
                    // Only into the vault the note was opened from.
                    if model.vaultPath == openedIn { model.saveText(unsaved, forNoteAt: path) }
                }
            }
        }
        .onChange(of: storedText) { _, newValue in
            // The file changed (a sync assigned markers, another device edited it). While
            // nothing is being typed, follow it; the shown text often does not change at all
            // because only hidden markers moved.
            guard !isDirty else { return }
            baseText = newValue
            let shown = TaskIDMasking.hidden(in: newValue)
            if shown != text { text = shown }
        }
        .confirmationDialog("Delete \u{201C}\(note?.displayTitle ?? "")\u{201D}?", isPresented: $confirmTrash) {
            Button("Delete", role: .destructive) {
                guard let note else { return }
                pendingSave?.cancel()
                pendingSave = nil
                isDirty = false
                model.trash(note)
            }
        } message: {
            Text("It goes to the Deleted list, where you can put it back.")
        }
        .alert("Rename \u{201C}\(note?.displayTitle ?? "")\u{201D}", isPresented: $renamingNote) {
            TextField("Title", text: $noteTitleDraft)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                guard let note else { return }
                flushSave()
                model.renameNote(note, to: noteTitleDraft)
            }
        } message: {
            Text("The file is renamed too, and every note that links to it is pointed at the new name.")
        }
        .sheet(item: $snippetToFill) { snippet in
            SnippetSheet(snippet: snippet) { answers in
                model.insert(snippet, answers: answers, into: path)
            }
        }
        .navigationTitle(note?.title ?? path)
        .toolbar {
            // The phone's navigation bar has room for a back button, a title and one control.
            // Everything went in as separate items and the segmented picker was squeezed to
            // three overlapping letters, so on a phone it is all one menu.
            if isPhone {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Mode", selection: $mode) {
                            ForEach(EditorMode.allCases) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        Divider()
                        if let note, note.kind != .inbox, note.kind != .daily {
                            Button {
                                noteTitleDraft = note.displayTitle
                                renamingNote = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                        }
                        if let note, model.canArchive(note) {
                            Button {
                                flushSave()
                                model.archive(note)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        if let note, note.kind != .inbox {
                            Button(role: .destructive) {
                                confirmTrash = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            } else {
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
                if let note, note.kind != .inbox, note.kind != .daily {
                    Button {
                        noteTitleDraft = note.displayTitle
                        renamingNote = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .help("Change this note's name; links to it follow")
                }
                if let note, note.kind != .inbox {
                    Button {
                        confirmTrash = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Delete this note; it waits in Deleted (⌘⌫)")
                    .keyboardShortcut(.delete, modifiers: [.command])
                }
            }
            }
        }
    }

    /// Mac and iPad, unchanged: a fixed column whose editor absorbs the leftover height.
    /// Builds 30 and 34 are both about this — anything here that reports its full
    /// intrinsic height makes the window grow past itself — so it is left alone.
    private var deskBody: some View {
        VStack(spacing: 0) {
            sections
            // The editor takes whatever height is left and never asks for more. Without this
            // guard, expanding a disclosure above it made the text editor report its full
            // text height as a minimum, and the window's content grew past the window.
            GeometryReader { geo in
                editorPane
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            Divider()
            addTaskBar
        }
    }

    /// The phone.
    ///
    /// The same column would not fit and could not be moved: nothing in it scrolled, so a
    /// note with two dozen tasks ran off both ends of the screen at once — the first tasks
    /// hidden under the navigation bar, the last under the tab bar, and no way to reach
    /// either. On a screen this size the whole page has to be one scrolling thing.
    ///
    /// The editor is given a height rather than the leftover space, because inside a scroll
    /// view there is no leftover space to take. The add-a-task bar is pinned as a safe-area
    /// inset instead of being the last row: it is the reason the screen is open, and it
    /// should not have to be scrolled to.
    private var phoneBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                sections
                editorPane
                    .frame(height: 320)
            }
        }
        // The phone has no third column, so the note screen itself carries the section's
        // colour (build 111). Same tint, same rule as the Mac's right-hand panel.
        .modeAccent(model.section?.tint ?? .secondary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                addTaskBar
            }
            .background(.bar)
        }
    }

    /// Everything above the editor: the note's own header, whatever agenda it carries, its
    /// tasks and its links.
    @ViewBuilder
    private var sections: some View {
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
                    HStack {
                        SectionLabel(title: note.openTasks.isEmpty ? "Tasks" : "Tasks, \(note.openTasks.count) open",
                                     count: nil, systemImage: "checklist", tint: note.tint)
                        Spacer()
                        let finished = note.tasks.count - note.openTasks.count
                        if finished > 0 {
                            Button {
                                hideFinishedTasks.toggle()
                            } label: {
                                Label(hideFinishedTasks ? "\(finished) finished hidden" : "Hide finished",
                                      systemImage: hideFinishedTasks ? "eye.slash" : "eye")
                                    .font(.caption)
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Show or hide tasks that are done or cancelled")
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            }
            let linksTo = notesLinkedTo(from: note)
            let linkedFrom = notesLinking(to: note)
            if !linksTo.isEmpty || !linkedFrom.isEmpty {
                DisclosureGroup(isExpanded: $showLinks) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !linksTo.isEmpty {
                            SectionLabel(title: "Links to", count: linksTo.count, systemImage: "arrow.up.right")
                                .font(.caption)
                            LinkedNotesList(notes: linksTo)
                        }
                        if !linkedFrom.isEmpty {
                            SectionLabel(title: "Linked from", count: linkedFrom.count, systemImage: "arrow.down.left")
                                .font(.caption)
                            LinkedNotesList(notes: linkedFrom)
                        }
                    }
                } label: {
                    SectionLabel(title: "Linked notes", count: linksTo.count + linkedFrom.count,
                                 systemImage: "link", tint: note.tint)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    /// The markdown itself: the raw text, the rendered version, or both side by side.
    private var editorPane: some View {
        HStack(spacing: 0) {
            if mode != .preview {
                MarkdownSyntaxEditor(text: $text, tint: note?.tint ?? .accentColor,
                                     linkDraft: $linkDraft, completion: $linkCompletion,
                                     openLink: { model.openWikiLink($0, from: path) },
                                     onLinkKey: handleLinkKey)
                    .onChange(of: text) { _, newValue in
                        scheduleSave(newValue)
                    }
                    // The list of titles sits over the editor, under the caret.
                    .overlay(alignment: .topLeading) { linkSuggestions }
                    .onChange(of: linkDraft) { _, _ in linkChoice = 0 }
            }
            if mode == .split {
                Divider()
            }
            if mode != .edit, let note {
                MarkdownPreview(note: note, beforeToggle: flushSave)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// What `[[` offers: the titles this note may link to, closest match first.
    private var linkTitles: [String] {
        guard let draft = linkDraft?.draft else { return [] }
        return WikiLinks.suggestions(for: draft.query, among: model.linkableTitles(from: path))
    }

    /// The arrow keys, Return and Escape while the list is up. They arrive from the text view,
    /// which has the focus; returning false lets the keystroke do its ordinary job.
    private func handleLinkKey(_ key: LinkKey) -> Bool {
        guard let draft = linkDraft?.draft, !linkTitles.isEmpty else { return false }
        switch key {
        case .down:
            linkChoice = min(linkChoice + 1, linkTitles.count - 1)
        case .up:
            linkChoice = max(linkChoice - 1, 0)
        case .enter:
            guard linkTitles.indices.contains(linkChoice) else { return false }
            linkCompletion = LinkCompletion(draft: draft, title: linkTitles[linkChoice])
        case .escape:
            linkDraft = nil
        }
        return true
    }

    @ViewBuilder
    private var linkSuggestions: some View {
        if let linkDraft, !linkTitles.isEmpty {
            // Inside the editor, whatever the cursor is doing: below the line when there is
            // room, above it when the cursor is near the bottom, and never off the right edge.
            // Build 114 put it under the caret and let it fall off the bottom (build 115).
            GeometryReader { geo in
                let height = min(CGFloat(linkTitles.count) * 30 + 10, 250)
                let below = linkDraft.caret.y + linkDraft.lineHeight + 4
                let fits = below + height <= geo.size.height
                let y = fits ? below : max(linkDraft.caret.y - height - 4, 0)
                WikiLinkList(titles: linkTitles, choice: $linkChoice, tint: note?.tint ?? .accentColor,
                             kindFor: { model.index.note(matching: $0)?.kind ?? model.note(at: path)?.kind ?? .resource },
                             pick: { title in linkCompletion = LinkCompletion(draft: linkDraft.draft, title: title) })
                    .frame(width: min(320, max(geo.size.width - 24, 160)))
                    .offset(x: min(max(linkDraft.caret.x - 6, 8), max(geo.size.width - 328, 8)),
                            y: min(max(y, 0), max(geo.size.height - height, 0)))
            }
            .zIndex(10)
        }
    }

    private var addTaskBar: some View {
        HStack {
            TextField("Add a task… (>2026-09-10 or >2026-09-10T14:30 for a date, !! for priority, #tag)", text: $newTask)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)
            Button("Add", action: addTask)
                .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
            Menu {
                ForEach(model.snippets) { snippet in
                    Button(snippet.name) { start(snippet) }
                }
            } label: {
                Label("Snippet", systemImage: "text.append")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(model.snippets.isEmpty)
            .help("Add a ready-made block of tasks. Edit them in Templates › Snippets.")
        }
        .padding(8)
    }

    /// A snippet with nothing to ask goes straight in; otherwise the sheet collects the
    /// words it wants first.
    private func start(_ snippet: Snippet) {
        guard !snippet.questions.isEmpty else {
            model.insert(snippet, answers: [:], into: path)
            return
        }
        snippetToFill = snippet
    }

    /// The notes this one points at: its `goal`/`area`/`parent`/`related` lines and its
    /// `[[links]]`.
    private func notesLinkedTo(from note: Note) -> [Note] {
        let index = model.index
        var seen = Set<String>()
        var result: [Note] = []
        for title in note.outgoingReferences + WikiLinks.titles(in: note.text) {
            guard let candidate = index.note(matching: title) ?? model.workNote(titled: title, near: note) else { continue }
            guard candidate.relativePath != note.relativePath,
                  seen.insert(candidate.relativePath).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    /// The notes that point at this one.
    private func notesLinking(to note: Note) -> [Note] {
        var seen = Set<String>()
        var result: [Note] = []
        for candidate in model.backlinks(to: note) {
            guard candidate.relativePath != note.relativePath,
                  seen.insert(candidate.relativePath).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    private func scheduleSave(_ newValue: String) {
        guard newValue != displayText else {
            isDirty = false
            return
        }
        isDirty = true
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            write(newValue)
        }
    }

    private func flushSave() {
        pendingSave?.cancel()
        pendingSave = nil
        if isDirty { write(text) }
    }

    /// Puts the hidden markers back and saves.
    private func write(_ shown: String) {
        model.saveText(TaskIDMasking.restored(shown, from: baseText), forNoteAt: path)
        isDirty = false
        baseText = model.note(at: path)?.text ?? baseText
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
            if note.kind == .area {
                AreaParentChip(model: model, note: note)
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

    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false

    /// The tasks to draw. Finished ones can be hidden, but never one that still has open
    /// work under it: a done parent with an open subtask stays, or the subtask would vanish.
    var visibleTasks: [TaskItem] {
        guard hideFinishedTasks else { return note.tasks }
        let tasks = note.tasks
        var keep = [Bool](repeating: true, count: tasks.count)
        for (i, task) in tasks.enumerated() where task.isDone {
            var hasOpenDescendant = false
            var j = i + 1
            while j < tasks.count, tasks[j].indentLevel > task.indentLevel {
                if !tasks[j].isDone { hasOpenDescendant = true; break }
                j += 1
            }
            keep[i] = hasOpenDescendant
        }
        return zip(tasks, keep).compactMap { $1 ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(visibleTasks, id: \.lineIndex) { task in
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
    @State private var renaming = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

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
                if renaming {
                    TextField("Task", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                        .onSubmit(commitRename)
                } else {
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
            TaskContextMenu(ref: ref, showNote: showNote, pickingDate: $pickingDate,
                            onAddSubtask: onAddSubtask, onRename: startRenaming)
        }
        .popover(isPresented: $pickingDate) {
            TaskDatePicker(ref: ref, isPresented: $pickingDate)
        }
    }

    /// The field shows the task the way the row does: without the #next marker, which
    /// `AppModel.renameTask` puts back so a rename never clears the next action.
    private func startRenaming() {
        draft = isNext ? Note.removingTag(Note.nextActionTag, from: ref.task.title) : ref.task.title
        renaming = true
        fieldFocused = true
    }

    private func commitRename() {
        renaming = false
        model.renameTask(ref, to: draft)
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

/// The list of titles that drops under the cursor while a `[[link]]` is being typed.
///
/// It only ever reads the text and hands a chosen title back: it never writes into the editor
/// itself, so typing cannot be interrupted by it. The arrow keys are taken only while it is on
/// screen, and Escape puts it away.
struct WikiLinkList: View {
    let titles: [String]
    @Binding var choice: Int
    let tint: Color
    let kindFor: (String) -> ParaKind
    let pick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.element) { index, title in
                Button {
                    pick(title)
                } label: {
                    HStack(spacing: 8) {
                        KindBadge(kind: kindFor(title), size: 16)
                        Text(title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(index == choice ? tint.opacity(0.22) : .clear,
                                in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(tint.opacity(0.35)))
        .shadow(radius: 12, y: 4)
    }
}

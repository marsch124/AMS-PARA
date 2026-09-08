import SwiftUI
import AMSParaCore

private extension TaskRef {
    /// Identifies a line while it sits in the list: the note and the line it is on.
    var triageID: String { "\(notePath)#\(task.lineIndex)" }
}

/// The Inbox section's middle column. There is only ever one inbox note, so a list of notes
/// would be a list of one; this is the thing you actually came to do — capture at the top,
/// then sort what is waiting, one line at a time.
struct InboxTriageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newItem = ""
    @State private var selection: String?
    @State private var pickingDateFor: TaskRef?
    @FocusState private var captureFocused: Bool

    private var inbox: Note? { model.notes(in: .inbox).first }

    private var items: [TaskRef] {
        guard let inbox else { return [] }
        return inbox.openTasks.filter { !$0.isSubtask }
            .map { TaskRef(notePath: inbox.relativePath, noteTitle: inbox.displayTitle, task: $0) }
    }

    private var selected: TaskRef? { items.first { $0.triageID == selection } }

    var body: some View {
        VStack(spacing: 0) {
            captureBar
            Divider()
            if items.isEmpty {
                EmptyStateView(title: "Inbox zero",
                               systemImage: "tray",
                               message: "Nothing left to sort. Anything you capture — here, from the menu bar, or from the share sheet on the phone — lands in this list.",
                               tint: SidebarSection.inbox.tint)
            } else {
                header
                List(selection: $selection) {
                    ForEach(items, id: \.triageID) { ref in
                        InboxRow(ref: ref, pickingDateFor: $pickingDateFor)
                            .tag(ref.triageID)
                    }
                }
            }
        }
        .focusable()
        .onKeyPress(.upArrow) { move(-1) }
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(KeyEquivalent("t")) { act { model.setDueDate($0, .today()) } }
        .onKeyPress(KeyEquivalent("m")) { act { model.setDueDate($0, .today().adding(days: 1)) } }
        .onKeyPress(KeyEquivalent("d")) { act { model.toggle($0) } }
        .onKeyPress(.delete) { act { model.deleteTask($0) } }
        .sheet(item: $pickingDateFor) { ref in
            TaskDatePicker(ref: ref, isPresented: Binding(get: { pickingDateFor != nil },
                                                         set: { if !$0 { pickingDateFor = nil } }))
        }
    }

    @ViewBuilder
    private var captureBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(SidebarSection.inbox.tint)
            TextField("Capture something…", text: $newItem)
                .textFieldStyle(.roundedBorder)
                .focused($captureFocused)
                .onSubmit(capture)
            Button("Add", action: capture)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            SectionLabel(title: items.count == 1 ? "1 to sort" : "\(items.count) to sort",
                         count: nil, systemImage: "tray.full", tint: SidebarSection.inbox.tint)
            Spacer()
            Text("T today · M tomorrow · D done · ⌫ delete")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: Doing things

    private func capture() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let inbox else { return }
        model.addTask(text, to: inbox.relativePath)
        newItem = ""
    }

    /// Runs a single-key action on the selected line, unless you are typing in the capture box.
    private func act(_ work: @escaping (TaskRef) -> Void) -> KeyPress.Result {
        guard !captureFocused, let ref = selected else { return .ignored }
        let ids = items.map(\.triageID)
        let after = ids.firstIndex(of: ref.triageID).map { $0 + 1 } ?? 0
        work(ref)
        selection = after < ids.count ? ids[after] : ids.last
        return .handled
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !captureFocused, !items.isEmpty else { return .ignored }
        let ids = items.map(\.triageID)
        let current = selection.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = min(max(current + delta, 0), ids.count - 1)
        selection = ids[next]
        return .handled
    }
}

/// One line waiting to be sorted, with everything you might do to it.
struct InboxRow: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var pickingDateFor: TaskRef?

    private var projects: [Note] {
        model.notes.filter { ($0.kind == .project || $0.kind == .area) && !$0.isArchived && $0.status != "done" }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.toggle(ref)
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(SidebarSection.inbox.tint)
            }
            .buttonStyle(.plain)
            .help("Mark as done")

            VStack(alignment: .leading, spacing: 2) {
                Text(Note.removingTag(Note.nextActionTag, from: ref.task.title))
                    .lineLimit(2)
                if let due = ref.task.dueDate {
                    Label(due.description, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(due < .today() ? Color.red : .secondary)
                }
            }
            Spacer(minLength: 6)
            actions
        }
        .padding(.vertical, 2)
        .contextMenu { menuItems }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 2) {
            Button { model.setDueDate(ref, .today()) } label: { Image(systemName: "sun.max") }
                .help("Due today")
            Button { model.setDueDate(ref, .today().adding(days: 1)) } label: { Image(systemName: "sunrise") }
                .help("Due tomorrow")
            Button { pickingDateFor = ref } label: { Image(systemName: "calendar") }
                .help("Pick a date…")
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .fixedSize()
            .help("File it somewhere")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var menuItems: some View {
        Menu("Move to") {
            ForEach(projects) { note in
                Button(note.displayTitle) { model.moveTask(ref, to: note.relativePath) }
            }
        }
        .disabled(projects.isEmpty)
        Menu("Turn into a note") {
            Button("Project") { model.makeNote(from: ref, kind: .project) }
            Button("Area") { model.makeNote(from: ref, kind: .area) }
            Button("Resource") { model.makeNote(from: ref, kind: .resource) }
            Button("Goal") { model.makeNote(from: ref, kind: .goal) }
        }
        Divider()
        Button("Block time for this…") { model.blockTime(for: ref) }
        Button("Remove the date") { model.setDueDate(ref, nil) }
            .disabled(ref.task.dueDate == nil)
        Divider()
        Button("Delete", role: .destructive) { model.deleteTask(ref) }
    }
}

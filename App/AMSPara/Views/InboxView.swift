import SwiftUI
import AMSParaCore

/// What the Inbox screen is working with. Both columns read it from here.
/// `@MainActor` because everything here touches `AppModel`, which is main-actor bound.
@MainActor
enum InboxItems {
    static func note(_ model: AppModel) -> Note? { model.notes(in: .inbox).first }

    /// The open, top-level lines waiting to be sorted.
    static func waiting(_ model: AppModel) -> [TaskRef] {
        guard let note = note(model) else { return [] }
        return note.openTasks.filter { !$0.isSubtask }
            .map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
    }

    static func selected(_ model: AppModel) -> TaskRef? {
        waiting(model).first { $0.triageID == model.inboxSelection }
    }

    /// Where a line can go: the working notes, most recently touched first.
    static func destinations(_ model: AppModel) -> [Note] {
        model.notes
            .filter { ($0.kind == .project || $0.kind == .area) && !$0.isArchived && $0.status != "done" }
            .sorted { $0.kind == $1.kind ? $0.displayTitle < $1.displayTitle : $0.kind == .project }
    }

    /// Moves a line on and selects whatever follows it, so sorting keeps its rhythm.
    static func file(_ ref: TaskRef, into path: String, model: AppModel) {
        let ids = waiting(model).map(\.triageID)
        let after = ids.firstIndex(of: ref.triageID).map { $0 + 1 } ?? 0
        model.moveTask(ref, to: path)
        model.inboxSelection = after < ids.count ? ids[after] : nil
    }
}

extension TaskRef {
    /// Identifies a line while it sits in the list: the note and the line it is on.
    var triageID: String { "\(notePath)#\(task.lineIndex)" }
}

/// The Inbox section's middle column. There is only ever one inbox note, so a list of notes
/// would be a list of one; this is the thing you actually came to do — capture at the top,
/// then sort what is waiting, one line at a time.
struct InboxTriageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newItem = ""
    @State private var pickingDateFor: TaskRef?
    @FocusState private var captureFocused: Bool

    private var inbox: Note? { InboxItems.note(model) }
    private var items: [TaskRef] { InboxItems.waiting(model) }
    private var selected: TaskRef? { InboxItems.selected(model) }

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
                List(selection: $model.inboxSelection) {
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
        .onChange(of: model.inboxSelection) { _, new in
            guard new != nil, model.selectedNotePath != nil else { return }
            model.afterUpdate { model.selectedNotePath = nil }
        }
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
        model.inboxSelection = after < ids.count ? ids[after] : ids.last
        return .handled
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !captureFocused, !items.isEmpty else { return .ignored }
        let ids = items.map(\.triageID)
        let current = model.inboxSelection.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = min(max(current + delta, 0), ids.count - 1)
        model.inboxSelection = ids[next]
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

/// The Inbox section's right-hand column: the line you are sorting, and where it can go.
/// Drag a line onto a destination, or select it and click one.
struct InboxFileItView: View {
    @EnvironmentObject private var model: AppModel

    private var selected: TaskRef? { InboxItems.selected(model) }
    private var destinations: [Note] { InboxItems.destinations(model) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "File it", count: nil, systemImage: "tray.and.arrow.down",
                         tint: SidebarSection.inbox.tint)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            selectedCard
                .padding(.horizontal, 16)
                .padding(.top, 10)
            SectionLabel(title: destinationsTitle, count: nil, systemImage: nil)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            if destinations.isEmpty {
                Text("You have no active projects or areas yet. Make one from a line with the button below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(destinations) { note in
                        DestinationRow(note: note, selected: selected)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            footer
                .padding(16)
        }
    }

    private var destinationsTitle: String {
        selected == nil ? "Where things go" : "Drop it on a destination, or click one"
    }

    @ViewBuilder
    private var selectedCard: some View {
        if let ref = selected {
            VStack(alignment: .leading, spacing: 6) {
                Text(Note.removingTag(Note.nextActionTag, from: ref.task.title))
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = ref.task.dueDate {
                    Label(due.description, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(due < .today() ? Color.red : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        } else {
            Text("Pick a line on the left, or drag one straight onto a destination.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button("Project") { make(.project) }
                Button("Area") { make(.area) }
                Button("Resource") { make(.resource) }
            } label: {
                Label("New note from this line…", systemImage: "plus")
            }
            .disabled(selected == nil)
            Button("Open the Inbox note") {
                model.selectedNotePath = InboxItems.note(model)?.relativePath
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
    }

    private func make(_ kind: ParaKind) {
        guard let ref = selected else { return }
        model.inboxSelection = nil
        model.makeNote(from: ref, kind: kind)
    }
}

/// One place a line can be filed, as a click target and a drop target.
struct DestinationRow: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let selected: TaskRef?
    @State private var hovering = false

    var body: some View {
        Button {
            if let selected { InboxItems.file(selected, into: note.relativePath, model: model) }
        } label: {
            HStack(spacing: 10) {
                TintStripe(color: note.kind.tint, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering && selected != nil ? Color.accentColor.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selected == nil)
        .onHover { hovering = $0 }
        .acceptsTaskDrop { ref in InboxItems.file(ref, into: note.relativePath, model: model) }
        .help(selected == nil ? "Select a line on the left first" : "Move it to \(note.displayTitle)")
    }

    private var subtitle: String {
        let open = note.openTasks.count
        let kind = note.kind == .project ? "Project" : "Area"
        return open == 0 ? kind : "\(kind) · \(open) open"
    }
}

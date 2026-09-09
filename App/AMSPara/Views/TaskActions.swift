import SwiftUI
import UniformTypeIdentifiers
import AMSParaCore

extension UTType {
    /// A task dragged inside the app (between notes, onto a day).
    static let amsParaTask = UTType(exportedAs: "com.schabbauer.amspara.task")
}

/// What a dragged task carries: enough to find it again in its note.
struct TaskTransfer: Codable, Transferable {
    var notePath: String
    var lineIndex: Int
    var title: String
    /// Set when a whole note was dragged rather than a task in it: the Map drags its boxes,
    /// and every task drop target ignores those instead of guessing at a task.
    var isNote: Bool?

    init(_ ref: TaskRef) {
        notePath = ref.notePath
        lineIndex = ref.task.lineIndex
        title = ref.task.title
    }

    init(note: Note) {
        notePath = note.relativePath
        lineIndex = -1
        title = note.displayTitle
        isNote = true
    }

    /// A drag that means nothing, for boxes on the Map that are not notes.
    static let nothing = TaskTransfer(note: Note(relativePath: "", kind: .resource))

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .amsParaTask)
    }
}

/// Makes a view accept a dropped task. The closure gets the task as it is in its note now.
struct TaskDropModifier: ViewModifier {
    @EnvironmentObject private var model: AppModel
    let perform: (TaskRef) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .background(targeted ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .dropDestination(for: TaskTransfer.self) { items, _ in
                guard let transfer = items.first, let ref = model.task(for: transfer) else { return false }
                perform(ref)
                return true
            } isTargeted: { targeted = $0 }
    }
}

extension View {
    func acceptsTaskDrop(_ perform: @escaping (TaskRef) -> Void) -> some View {
        modifier(TaskDropModifier(perform: perform))
    }
}

/// The right-click menu shared by every task row: reschedule, repeat, next action, time block, move.
struct TaskContextMenu: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let showNote: Bool
    @Binding var pickingDate: Bool
    var onAddSubtask: (() -> Void)?
    var onRename: (() -> Void)?

    private var note: Note? { model.note(at: ref.notePath) }
    private var inboxPath: String { model.vault?.config.inboxFile ?? "Inbox.md" }

    /// The notes a task can be moved to: the active projects, then the areas with their
    /// sub-areas under them, in the same order as the sidebar lists.
    private func destinations(_ kind: ParaKind) -> [Note] {
        let listed = kind == .area ? model.index.areasInFamilyOrder() : model.notes.filter { $0.kind == kind }
        return listed.filter {
            !$0.isArchived && $0.status != "done" && $0.relativePath != ref.notePath
        }
    }

    /// Sub-areas read as "Mobility \u{203A} Yoga", so the menu is not a flat list of words.
    private func label(for note: Note) -> String {
        guard let parent = model.index.parentArea(of: note) else { return note.displayTitle }
        return "\(parent.displayTitle) \u{203A} \(note.displayTitle)"
    }
    private var isNext: Bool { ref.task.tags.contains(Note.nextActionTag) }

    private static let repeatChoices: [RepeatRule] = [
        RepeatRule(unit: .day), RepeatRule(unit: .week), RepeatRule(count: 2, unit: .week),
        RepeatRule(unit: .month), RepeatRule(count: 3, unit: .month), RepeatRule(unit: .year),
    ]

    var body: some View {
        Menu("Reschedule") {
            Button("Today") { model.setDueDate(ref, .today()) }
            Button("Tomorrow") { model.setDueDate(ref, DateOnly.today().adding(days: 1)) }
            Button("Next Monday") { model.setDueDate(ref, Self.nextMonday()) }
            Button("In a week") { model.setDueDate(ref, DateOnly.today().adding(days: 7)) }
            Divider()
            Button("Pick a date…") { pickingDate = true }
            if ref.task.dueDate != nil {
                Button("Remove date") { model.setDueDate(ref, nil) }
            }
        }
        Menu("Repeat") {
            Button(ref.task.repeatRule == nil ? "✓ Does not repeat" : "Does not repeat") { model.setRepeat(ref, nil) }
            Divider()
            ForEach(Self.repeatChoices, id: \.description) { rule in
                Button(ref.task.repeatRule == rule ? "✓ \(rule.label)" : rule.label) { model.setRepeat(ref, rule) }
            }
        }
        if note?.kind == .project, !ref.task.isSubtask {
            if isNext {
                Button("Clear next action") { model.clearNextAction(ref) }
            } else {
                Button("Make this the next action") { model.makeNextAction(ref) }
            }
        }
        Button("Block time for this…") { model.blockTime(for: ref) }
        if !ref.task.isSubtask {
            Menu("Move to") {
                if ref.notePath != inboxPath {
                    Button("Inbox") { model.moveTask(ref, to: inboxPath) }
                    Divider()
                }
                ForEach(destinations(.project)) { note in
                    Button(note.displayTitle) { model.moveTask(ref, to: note.relativePath) }
                }
                if !destinations(.project).isEmpty, !destinations(.area).isEmpty {
                    Divider()
                }
                ForEach(destinations(.area)) { note in
                    Button(label(for: note)) { model.moveTask(ref, to: note.relativePath) }
                }
            }
        }
        if let onRename {
            Button("Rename…", action: onRename)
        }
        if let onAddSubtask {
            Button("Add subtask…", action: onAddSubtask)
        }
        if showNote, let note {
            Divider()
            Button("Open \(note.displayTitle)") { model.show(note) }
        }
    }

    static func nextMonday(calendar: Calendar = .current) -> DateOnly {
        var day = DateOnly.today().adding(days: 1)
        for _ in 0..<7 {
            if let date = day.date(calendar: calendar), calendar.component(.weekday, from: date) == 2 { return day }
            day = day.adding(days: 1)
        }
        return day
    }
}

/// A small date picker shown from "Pick a date…".
struct TaskDatePicker: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var isPresented: Bool
    @State private var date = Date()

    var body: some View {
        VStack(spacing: 10) {
            DatePicker("Due", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Set date") {
                    model.setDueDate(ref, DateOnly(date))
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { date = ref.task.dueDate?.date() ?? Date() }
    }
}

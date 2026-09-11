import SwiftUI
import ParagonCore

/// Every open task in the vault, grouped by the note it lives in. The one place to answer
/// "what is actually on my plate", without a search you have to remember.
struct AllActionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var scope: Scope = .everything

    enum Scope: String, CaseIterable, Identifiable {
        case everything = "All"
        case dated = "With a date"
        case undated = "No date"
        case next = "Next actions"

        var id: String { rawValue }
    }

    /// Notes in the order the sidebar lists them, each with the tasks that pass the filter.
    private var groups: [(note: Note, tasks: [TaskRef])] {
        let refs = model.index.openTasks()
        var byPath: [String: [TaskRef]] = [:]
        for ref in refs where keep(ref) {
            byPath[ref.notePath, default: []].append(ref)
        }
        return model.notes.compactMap { note in
            guard let tasks = byPath[note.relativePath], !tasks.isEmpty else { return nil }
            return (note, tasks.sorted(by: byDueThenOrder))
        }
    }

    private func keep(_ ref: TaskRef) -> Bool {
        switch scope {
        case .everything: return true
        case .dated: return ref.task.dueDate != nil
        case .undated: return ref.task.dueDate == nil
        case .next: return ref.task.tags.contains(Note.nextActionTag)
        }
    }

    private func byDueThenOrder(_ a: TaskRef, _ b: TaskRef) -> Bool {
        switch (a.task.dueDate, b.task.dueDate) {
        case let (x?, y?): return x == y ? a.task.lineIndex < b.task.lineIndex : x < y
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.task.lineIndex < b.task.lineIndex
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            let groups = groups
            if groups.isEmpty {
                EmptyStateView(title: emptyTitle,
                               systemImage: "checkmark.circle",
                               message: "Nothing open here. Capture something in the Inbox, or change the filter above.",
                               tint: SidebarSection.allActions.tint)
            } else {
                List(selection: model.noteSelection) {
                    ForEach(groups, id: \.note.relativePath) { group in
                        Section {
                            ForEach(group.tasks) { ref in
                                TaskRow(ref: ref, showNote: false) { model.toggle(ref) }
                                    .tag(ref.notePath)
                            }
                        } header: {
                            HStack {
                                SectionLabel(title: group.note.displayTitle,
                                             count: group.tasks.count,
                                             systemImage: SidebarSection.kind(group.note.kind).systemImage,
                                             tint: group.note.tint)
                                Spacer()
                                Button("Open") { model.show(section: .kind(group.note.kind), notePath: group.note.relativePath) }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch scope {
        case .everything: return "Nothing open"
        case .dated: return "Nothing with a date"
        case .undated: return "Everything has a date"
        case .next: return "No next actions"
        }
    }
}

import SwiftUI
import ParagonCore

/// Everything due today or overdue, plus undated tasks marked `!!` or `!!!`.
struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let index = model.index
        let today = DateOnly.today()
        let dated = index.openTasks(dueOnOrBefore: today)
        let overdue = dated.filter { ($0.task.dueDate ?? today) < today }
        let dueToday = dated.filter { $0.task.dueDate == today }
        let important = index.openTasks().filter { $0.task.dueDate == nil && $0.task.priority >= 2 }
        let shown = Set((dated + important).map(\.id))
        let nextActions = index.nextActions().filter { !shown.contains($0.id) }
        let todayNotePath = model.vault?.dailyNotePath(for: today)
        let fromTodayNote = (model.todayNote?.openTasks ?? [])
            .filter { $0.dueDate == nil }
            .map { TaskRef(notePath: todayNotePath ?? "", noteTitle: "Today's note", task: $0) }

        List(selection: model.noteSelection) {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(today.date()?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? today.description)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    let open = overdue.count + dueToday.count
                    Text(open == 0 ? "Nothing due" : "\(open) due")
                        .font(.callout)
                        .foregroundStyle(overdue.isEmpty ? .secondary : Color.red)
                }
                .listRowSeparator(.hidden)
            }
            if model.showsCalendarEvents {
                Section("Calendar") {
                    CalendarEventRows(date: today)
                }
            }
            Section {
                Button {
                    model.openDailyNote(for: today)
                } label: {
                    Label(model.todayNote == nil ? "Create today's note" : "Open today's note", systemImage: "calendar")
                        .foregroundStyle(ParaKind.daily.tint)
                }
                if !fromTodayNote.isEmpty {
                    rows(fromTodayNote)
                }
            }
            if !nextActions.isEmpty {
                Section("Next actions") { rows(nextActions) }
            }
            if !overdue.isEmpty {
                Section("Overdue") { rows(overdue) }
            }
            Section("Due today") {
                if dueToday.isEmpty {
                    Text(overdue.isEmpty && nextActions.isEmpty
                         ? "Nothing is due today. Give a task a date, or pick a next action in a project."
                         : "Nothing else is due today.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    rows(dueToday)
                }
            }
            if !important.isEmpty {
                Section("Important, no date") { rows(important) }
            }
        }
        .task(id: today) { await model.loadEvents(for: today) }
    }

    private func rows(_ refs: [TaskRef]) -> some View {
        ForEach(refs) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                .tag(ref.notePath)
        }
    }
}

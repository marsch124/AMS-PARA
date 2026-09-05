import SwiftUI
import AMSParaCore

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

        List(selection: $model.selectedNotePath) {
            if !overdue.isEmpty {
                Section("Overdue") { rows(overdue) }
            }
            Section("Today") {
                if dueToday.isEmpty {
                    Text("Nothing due today.").foregroundStyle(.secondary)
                } else {
                    rows(dueToday)
                }
            }
            if !important.isEmpty {
                Section("Important, no date") { rows(important) }
            }
        }
    }

    private func rows(_ refs: [TaskRef]) -> some View {
        ForEach(refs) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                .tag(ref.notePath)
        }
    }
}

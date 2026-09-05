import SwiftUI
import AMSParaCore

/// Content column for the Calendar section: pick a day, see its daily note and what is due.
struct CalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pickerDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Day", selection: $pickerDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .onChange(of: pickerDate) { _, newValue in
                    model.openDailyNote(for: DateOnly(newValue))
                }
            HStack {
                Button("Today") {
                    pickerDate = Date()
                    model.openDailyNote(for: .today())
                }
                Spacer()
                let due = model.index.openTasks(dueOn: model.selectedDate).count
                Text(due == 0 ? "Nothing due" : "\(due) due")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            List(model.notes(in: .calendar), selection: $model.selectedNotePath) { note in
                DailyNoteRow(note: note)
                    .tag(note.relativePath)
            }
        }
        .onAppear {
            if let d = model.selectedDate.date() { pickerDate = d }
        }
    }
}

struct DailyNoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.displayTitle)
                .font(.headline)
            let open = note.openTasks.count
            let total = note.tasks.count
            Text(total == 0 ? "No tasks" : "\(open) open of \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

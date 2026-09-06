import SwiftUI
import AMSParaCore

/// What got done, day by day, for the last 30 days.
struct DoneView: View {
    @EnvironmentObject private var model: AppModel

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f
    }()

    var body: some View {
        let today = DateOnly.today()
        let days: [(DateOnly, [TaskRef])] = (0..<30).compactMap { offset in
            let day = today.adding(days: -offset)
            let done = model.index.tasksCompleted(on: day)
            return done.isEmpty ? nil : (day, done)
        }
        let thisWeek = days.filter { WeekRef.current().contains($0.0) }.reduce(0) { $0 + $1.1.count }
        let total = days.reduce(0) { $0 + $1.1.count }
        VStack(spacing: 0) {
            HStack {
                Label("\(thisWeek) done this week", systemImage: "checkmark.circle")
                Spacer()
                Text("\(total) in 30 days")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            List(selection: model.noteSelection) {
                if days.isEmpty {
                    Text("Nothing completed in the last 30 days. Ticked tasks show up here with the day they were done.")
                        .foregroundStyle(.secondary)
                }
                ForEach(days, id: \.0) { entry in
                    let (day, refs) = entry
                    Section {
                        ForEach(refs) { ref in
                            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                                .tag(ref.notePath)
                        }
                    } header: {
                        HStack {
                            Text(Self.title(for: day, today: today))
                            Spacer()
                            Text("\(refs.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private static func title(for day: DateOnly, today: DateOnly) -> String {
        if day == today { return "Today" }
        if day == today.adding(days: -1) { return "Yesterday" }
        return day.date().map(dayFormatter.string(from:)) ?? day.description
    }
}

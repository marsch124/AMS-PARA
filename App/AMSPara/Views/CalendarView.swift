import SwiftUI
import AMSParaCore

/// Content column for the Calendar section: a day picker, a week overview or a month grid.
struct CalendarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $model.calendarMode) {
                ForEach(AppModel.CalendarMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            switch model.calendarMode {
            case .day: DayCalendarView()
            case .week: WeekOverviewView()
            case .month: MonthOverviewView()
            }
        }
    }
}

struct DayCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pickerDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Day", selection: $pickerDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .onChange(of: pickerDate) { _, newValue in
                    let day = DateOnly(newValue)
                    if day != model.selectedDate { model.openDailyNote(for: day) }
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
            HStack {
                Text(note.displayTitle)
                    .font(.headline)
                if note.isWeeklyNote {
                    Text("week")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
            }
            let open = note.openTasks.count
            let total = note.tasks.count
            Text(total == 0 ? "No tasks" : "\(open) open of \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Seven days with what is due and what got done, plus the weekly note.
struct WeekOverviewView: View {
    @EnvironmentObject private var model: AppModel

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f
    }()

    var body: some View {
        let overview = model.index.weekOverview(for: model.selectedWeek)
        VStack(spacing: 0) {
            HStack {
                Button { model.selectedWeek = model.selectedWeek.adding(weeks: -1) } label: { Image(systemName: "chevron.left") }
                Button("This week") { model.selectedWeek = .current() }
                Button { model.selectedWeek = model.selectedWeek.adding(weeks: 1) } label: { Image(systemName: "chevron.right") }
                Spacer()
                Text("\(overview.dueCount) due · \(overview.completedCount) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            List(selection: $model.selectedNotePath) {
                Section {
                    Button {
                        model.openWeeklyNote(for: overview.week)
                    } label: {
                        Label(overview.weeklyNotePath == nil ? "Create weekly note" : "Open weekly note", systemImage: "calendar.badge.clock")
                    }
                    .tag(overview.weeklyNotePath ?? "")
                } header: {
                    Text(overview.week.title)
                }
                ForEach(overview.days) { day in
                    Section {
                        if day.due.isEmpty && day.undated.isEmpty && day.completed.isEmpty {
                            Text("Nothing planned")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(day.due + day.undated) { ref in
                            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                                .tag(ref.notePath)
                        }
                        if !day.completed.isEmpty {
                            Text("\(day.completed.count) done: " + day.completed.map(\.task.title).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    } header: {
                        HStack {
                            Text(dayTitle(day.date))
                                .fontWeight(day.date == .today() ? .bold : .regular)
                            if day.dailyNotePath != nil {
                                Image(systemName: "doc.text")
                                    .font(.caption2)
                            }
                            Spacer()
                            Button("Open day") { model.openDailyNote(for: day.date) }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }

    private func dayTitle(_ date: DateOnly) -> String {
        date.date().map(Self.dayFormatter.string(from:)) ?? date.description
    }
}

/// A month grid with per-day counts of due and completed tasks.
struct MonthOverviewView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols: [String] = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }()

    var body: some View {
        let overview = model.index.monthOverview(for: model.selectedMonth)
        let leading = (model.selectedMonth.firstDay.date(calendar: WeekRef.calendar).map { WeekRef.calendar.component(.weekday, from: $0) } ?? 2 + 5) % 7
        VStack(spacing: 0) {
            HStack {
                Button { model.selectedMonth = model.selectedMonth.adding(months: -1) } label: { Image(systemName: "chevron.left") }
                Button("This month") { model.selectedMonth = .current() }
                Button { model.selectedMonth = model.selectedMonth.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                Spacer()
                Text(overview.month.title)
                    .font(.headline)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 44) }
                    ForEach(overview.days) { day in
                        MonthDayCell(day: day, isSelected: day.date == model.selectedDate)
                            .onTapGesture { model.openDailyNote(for: day.date) }
                    }
                }
                .padding(8)
                Text("\(overview.dueCount) tasks due this month, \(overview.completedCount) completed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
    }
}

struct MonthDayCell: View {
    let day: DayOverview
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.date.day)")
                .font(.caption)
                .fontWeight(day.date == .today() ? .bold : .regular)
            HStack(spacing: 3) {
                if !day.due.isEmpty {
                    Text("\(day.due.count)")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(day.overdueCount > 0 ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.2), in: Capsule())
                }
                if !day.completed.isEmpty {
                    Text("✓\(day.completed.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if day.dailyNotePath != nil && day.due.isEmpty && day.completed.isEmpty {
                    Circle().fill(Color.accentColor).frame(width: 4, height: 4)
                }
            }
            .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .accessibilityLabel("\(day.date.description), \(day.due.count) due, \(day.completed.count) done")
    }
}

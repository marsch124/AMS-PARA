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

/// The day view: a header for the selected day, a month grid of our own with week numbers
/// and per-day dots, and the day itself below — its events, what is due, what got done.
struct DayCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var gridMonth: MonthRef = .current()

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM y")
        return f
    }()

    var body: some View {
        let day = model.selectedDate
        let overview = model.index.dayOverview(for: day)
        VStack(spacing: 0) {
            header(day: day, overview: overview)
            Divider()
            MonthGrid(month: gridMonth,
                      selected: day,
                      previous: { gridMonth = gridMonth.adding(months: -1) },
                      next: { gridMonth = gridMonth.adding(months: 1) },
                      pick: { picked in model.afterUpdate { model.openDailyNote(for: picked) } })
            Divider()
            dayContents(day: day, overview: overview)
        }
        .focusable()
        .onKeyPress(.leftArrow) { move(days: -1); return .handled }
        .onKeyPress(.rightArrow) { move(days: 1); return .handled }
        .onAppear { gridMonth = MonthRef(containing: day) }
        .onChange(of: model.selectedDate) { _, new in
            let month = MonthRef(containing: new)
            if month != gridMonth { gridMonth = month }
        }
        .task(id: day) { await model.loadEvents(for: day) }
    }

    private func move(days: Int) {
        let next = model.selectedDate.adding(days: days, calendar: WeekRef.calendar)
        model.afterUpdate { model.openDailyNote(for: next) }
    }

    /// "v. 37 · 3 due · 2 events". A plain function, not a view builder: it is only text.
    private func summary(day: DateOnly, overview: DayOverview) -> String {
        let events = model.events(on: day).count
        var parts = ["v. \(WeekRef(containing: day).week)"]
        if !overview.due.isEmpty { parts.append("\(overview.due.count) due") }
        if events > 0 { parts.append(events == 1 ? "1 event" : "\(events) events") }
        if !overview.completed.isEmpty { parts.append("\(overview.completed.count) done") }
        if overview.due.isEmpty && events == 0 && overview.completed.isEmpty { parts.append("nothing planned") }
        return parts.joined(separator: " · ")
    }

    /// The day in words, its week number, and what it holds.
    @ViewBuilder
    private func header(day: DateOnly, overview: DayOverview) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayTitle(day))
                    .font(.title3.weight(.semibold))
                Text(summary(day: day, overview: overview))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 2) {
                Button { move(days: -1) } label: { Image(systemName: "chevron.left") }
                    .help("Previous day")
                Button("Today") { model.afterUpdate { model.openDailyNote(for: .today()) } }
                    .disabled(day == .today())
                Button { move(days: 1) } label: { Image(systemName: "chevron.right") }
                    .help("Next day")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// What the selected day actually holds, rather than a list of every daily note.
    @ViewBuilder
    private func dayContents(day: DateOnly, overview: DayOverview) -> some View {
        List(selection: model.noteSelection) {
            if model.showsCalendarEvents {
                Section("Events") {
                    CalendarEventRows(date: day)
                }
            }
            Section("Due") {
                if overview.due.isEmpty {
                    Text("Nothing due.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(overview.due) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                        .tag(ref.notePath)
                }
            }
            if !overview.undated.isEmpty {
                Section("In the daily note") {
                    ForEach(overview.undated) { ref in
                        TaskRow(ref: ref, showNote: false) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                }
            }
            if !overview.completed.isEmpty {
                Section("Done") {
                    ForEach(overview.completed) { ref in
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                }
            }
            Section {
                Button {
                    model.afterUpdate { model.openDailyNote(for: day) }
                } label: {
                    Label(overview.dailyNotePath == nil ? "Create the daily note" : "Open the daily note",
                          systemImage: "doc.text")
                }
                .tag(overview.dailyNotePath ?? "")
            }
        }
    }

    private func dayTitle(_ date: DateOnly) -> String {
        date.date().map(Self.longDate.string(from:)) ?? date.description
    }
}

/// A month laid out by hand: week numbers down the left, a cell per day with dots for what
/// it holds. Apple's graphical DatePicker cannot show any of that and sizes itself.
struct MonthGrid: View {
    @EnvironmentObject private var model: AppModel
    let month: MonthRef
    let selected: DateOnly
    let previous: () -> Void
    let next: () -> Void
    let pick: (DateOnly) -> Void

    private static let weekdaySymbols: [String] = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }()

    /// The days of the month padded with nils so every row is a Monday-to-Sunday week.
    private var rows: [[DateOnly?]] {
        let firstWeekday = month.firstDay.date(calendar: WeekRef.calendar)
            .map { WeekRef.calendar.component(.weekday, from: $0) } ?? 2
        let leading = (firstWeekday + 5) % 7
        var cells: [DateOnly?] = Array(repeating: nil, count: leading) + month.days.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(month.title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button { previous() } label: { Image(systemName: "chevron.left") }
                    .help("Previous month")
                Button { next() } label: { Image(systemName: "chevron.right") }
                    .help("Next month")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    Text("")
                        .frame(width: 22)
                    ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        Text(weekNumber(of: rows[row]))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 22)
                        ForEach(0..<7, id: \.self) { column in
                            if let date = rows[row][column] {
                                MonthGridCell(date: date,
                                              overview: model.index.dayOverview(for: date),
                                              events: model.events(on: date).count,
                                              isSelected: date == selected)
                                    .onTapGesture { pick(date) }
                                    .acceptsTaskDrop { ref in model.setDueDate(ref, date) }
                            } else {
                                Color.clear.frame(height: 34)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private func weekNumber(of row: [DateOnly?]) -> String {
        guard let day = row.compactMap({ $0 }).first else { return "" }
        return "\(WeekRef(containing: day).week)"
    }
}

/// One day in the month grid: the number, and dots for tasks, events and a daily note.
struct MonthGridCell: View {
    let date: DateOnly
    let overview: DayOverview
    let events: Int
    let isSelected: Bool

    private var isToday: Bool { date == .today() }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(date.day)")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isSelected ? Color.white : (isToday ? ParaKind.daily.tint : Color.primary))
                .frame(width: 22, height: 20)
                .background {
                    if isSelected {
                        Circle().fill(ParaKind.daily.tint)
                    } else if isToday {
                        Circle().strokeBorder(ParaKind.daily.tint, lineWidth: 1.5)
                    }
                }
            HStack(spacing: 3) {
                if !overview.due.isEmpty {
                    Circle().fill(overview.overdueCount > 0 ? Color.red : ParaKind.daily.tint)
                        .frame(width: 4, height: 4)
                }
                if events > 0 {
                    Circle().fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                }
                if overview.dailyNotePath != nil {
                    Circle().fill(Color.secondary.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .contentShape(Rectangle())
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private var helpText: String {
        var parts: [String] = [date.description]
        if !overview.due.isEmpty { parts.append("\(overview.due.count) due") }
        if events > 0 { parts.append("\(events) events") }
        if overview.dailyNotePath != nil { parts.append("daily note") }
        return parts.joined(separator: ", ")
    }
}

struct DailyNoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: ParaKind.daily.tint, height: 30)
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
            List(selection: model.noteSelection) {
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
                        .acceptsTaskDrop { ref in model.setDueDate(ref, day.date) }
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
        // Weekday of the 1st (1 = Sunday … 7 = Saturday) turned into blank cells before it in a Monday-first grid.
        let firstWeekday = model.selectedMonth.firstDay.date(calendar: WeekRef.calendar).map { WeekRef.calendar.component(.weekday, from: $0) } ?? 2
        let leading = (firstWeekday + 5) % 7
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
                            .acceptsTaskDrop { ref in model.setDueDate(ref, day.date) }
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
                        .background(day.overdueCount > 0 ? Color.red.opacity(0.22) : ParaKind.daily.tint.opacity(0.25), in: Capsule())
                }
                if !day.completed.isEmpty {
                    Text("✓\(day.completed.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if day.dailyNotePath != nil && day.due.isEmpty && day.completed.isEmpty {
                    Circle().fill(ParaKind.daily.tint).frame(width: 4, height: 4)
                }
            }
            .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isSelected ? ParaKind.daily.tint.opacity(0.20) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .accessibilityLabel("\(day.date.description), \(day.due.count) due, \(day.completed.count) done")
    }
}

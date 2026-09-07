import SwiftUI
import AMSParaCore

/// The right-hand column while the Calendar section is open: the day drawn as a schedule,
/// or the daily note. Everywhere else the column is the note editor, unchanged.
struct CalendarDetailView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("calendarDetailShowsNote") private var showsNote = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $showsNote) {
                Text("Schedule").tag(false)
                Text("Note").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)
            Divider()
            content
        }
        .onChange(of: model.selectedNotePath) { _, path in
            // Picking a note in the middle column means you want to read it.
            if path != nil { showsNote = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if showsNote {
            if let path = model.selectedNotePath, model.note(at: path) != nil {
                NoteEditorView(path: path)
                    .id(path)
            } else {
                EmptyStateView(title: "No note for this day yet",
                               systemImage: "doc.text",
                               message: "Open or create the daily note from the list on the left, and it appears here.",
                               tint: ParaKind.daily.tint)
            }
        } else {
            DayScheduleView(day: model.selectedDate)
        }
    }
}

/// One thing that sits somewhere on the day: a calendar event, a time block of yours, or a
/// task with a time on it. Kept as one type so the timeline can lay them out together.
struct ScheduleItem: Identifiable {
    enum Kind: Equatable {
        case event
        case block(String)
        case task
    }

    var id: String
    var title: String
    var start: Date
    var end: Date
    var color: Color
    var kind: Kind
    var subtitle: String

    var isBlock: Bool { if case .block = kind { return true } else { return false } }
}

/// What the one sheet in the schedule is showing.
private enum ScheduleSheet: Identifiable {
    case new(Date?)
    case edit(TimeBlock)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let block): return block.id
        }
    }
}

/// The day as a timeline: hours down the side, events and time blocks in place, a line for
/// now. Drop a task on an hour to block that hour for it.
struct DayScheduleView: View {
    @EnvironmentObject private var model: AppModel
    let day: DateOnly

    @State private var sheet: ScheduleSheet?
    @State private var now = Date()

    private static let hourHeight: CGFloat = 46
    private static let gutter: CGFloat = 52
    private let calendar = Calendar.current

    private static let hourLabel: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j")
        return f
    }()

    private static let timeLabel: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jm")
        return f
    }()

    var body: some View {
        let items = timedItems()
        let range = hourRange(items)
        VStack(spacing: 0) {
            header
            Divider()
            untimedStrip
            ScrollView {
                timeline(items: items, range: range)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .task(id: day) {
            await model.loadEvents(for: day)
            await model.loadTimeBlocks()
        }
        .task {
            // The now line only has to be roughly right.
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new(let start):
                TimeBlockSheet(block: nil, day: day, start: start) { sheet = nil }
            case .edit(let block):
                TimeBlockSheet(block: block, day: day, start: nil) { sheet = nil }
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Schedule")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button {
                sheet = .new(defaultStart())
            } label: {
                Label("Block time", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .help("Reserve a block of time on this day")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// All-day events and tasks due today without a time, so they are not lost off the clock.
    @ViewBuilder
    private var untimedStrip: some View {
        let chips = untimedChips()
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips) { chip in
                        HStack(spacing: 5) {
                            Circle().fill(chip.color).frame(width: 6, height: 6)
                            Text(chip.title).font(.caption).lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            Divider()
        }
    }

    @ViewBuilder
    private func timeline(items: [ScheduleItem], range: ClosedRange<Int>) -> some View {
        let laidOut = lanes(for: items)
        GeometryReader { geometry in
            let width = max(80, geometry.size.width - Self.gutter)
            ZStack(alignment: .topLeading) {
                hourGrid(range: range, width: width)
                ForEach(laidOut) { placed in
                    ScheduleItemView(item: placed.item)
                        .frame(width: max(40, (width - 6) / CGFloat(placed.lanes)) - 4,
                               height: max(18, height(of: placed.item)))
                        .offset(x: Self.gutter + (width - 6) / CGFloat(placed.lanes) * CGFloat(placed.lane),
                                y: offset(of: placed.item.start, in: range))
                        .onTapGesture { open(placed.item) }
                }
                if let line = nowOffset(in: range) {
                    HStack(spacing: 0) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Rectangle().fill(Color.red).frame(height: 1)
                    }
                    .offset(x: Self.gutter - 3, y: line)
                }
            }
        }
        .frame(height: CGFloat(range.upperBound - range.lowerBound) * Self.hourHeight)
    }

    @ViewBuilder
    private func hourGrid(range: ClosedRange<Int>, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(range.lowerBound..<range.upperBound, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourText(hour))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: Self.gutter - 6, alignment: .trailing)
                        .padding(.trailing, 6)
                        .offset(y: -5)
                    VStack(spacing: 0) {
                        Divider()
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: Self.hourHeight)
                .contentShape(Rectangle())
                .acceptsTaskDrop { ref in blockTime(for: ref, at: hour) }
                .onTapGesture(count: 2) { sheet = .new(date(hour: hour)) }
            }
        }
    }

    // MARK: Data

    private func timedItems() -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        for event in model.events(on: day) where !event.isAllDay {
            if event.isTimeBlock, let block = model.timeBlocks.first(where: { $0.id == event.id }) {
                items.append(ScheduleItem(id: block.id, title: block.title, start: block.start, end: block.end,
                                          color: SidebarSection.timeBlocks.tint, kind: .block(block.id),
                                          subtitle: timeText(block.start, block.end)))
            } else {
                items.append(ScheduleItem(id: event.id, title: event.title, start: event.start, end: event.end,
                                          color: event.color, kind: .event,
                                          subtitle: timeText(event.start, event.end)))
            }
        }
        for ref in model.index.openTasks(dueOn: day) {
            guard ref.task.dueTime != nil, let start = ref.task.dueMoment(calendar: calendar) else { continue }
            items.append(ScheduleItem(id: "task-\(ref.notePath)-\(ref.task.lineIndex)", title: ref.task.title,
                                      start: start, end: start.addingTimeInterval(1800),
                                      color: ParaKind.daily.tint, kind: .task, subtitle: ref.noteTitle))
        }
        return items.sorted { $0.start < $1.start }
    }

    private struct Chip: Identifiable {
        var id: String
        var title: String
        var color: Color
    }

    private func untimedChips() -> [Chip] {
        var chips: [Chip] = []
        for event in model.events(on: day) where event.isAllDay {
            chips.append(Chip(id: event.id, title: event.title, color: event.color))
        }
        for ref in model.index.openTasks(dueOn: day) where ref.task.dueTime == nil {
            chips.append(Chip(id: "\(ref.notePath)-\(ref.task.lineIndex)", title: ref.task.title, color: ParaKind.daily.tint))
        }
        return chips
    }

    /// Overlapping items are put side by side: each one takes the first lane that is free.
    private func lanes(for items: [ScheduleItem]) -> [PlacedItem] {
        var result: [PlacedItem] = []
        var cluster: [(item: ScheduleItem, lane: Int)] = []
        var laneEnds: [Date] = []

        func flush() {
            let count = max(1, laneEnds.count)
            result.append(contentsOf: cluster.map { PlacedItem(item: $0.item, lane: $0.lane, lanes: count) })
            cluster.removeAll()
            laneEnds.removeAll()
        }

        for item in items {
            if let latest = laneEnds.max(), item.start >= latest { flush() }
            var lane = laneEnds.firstIndex { $0 <= item.start }
            if lane == nil {
                laneEnds.append(item.end)
                lane = laneEnds.count - 1
            } else {
                laneEnds[lane!] = item.end
            }
            cluster.append((item, lane!))
        }
        flush()
        return result
    }

    private func hourRange(_ items: [ScheduleItem]) -> ClosedRange<Int> {
        var low = 7
        var high = 19
        for item in items {
            low = min(low, calendar.component(.hour, from: item.start))
            high = max(high, calendar.component(.hour, from: item.end) + 1)
        }
        return max(0, low - 1)...min(24, max(high, low + 6))
    }

    // MARK: Geometry

    private func offset(of date: Date, in range: ClosedRange<Int>) -> CGFloat {
        let minutes = CGFloat(calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date))
        return (minutes - CGFloat(range.lowerBound * 60)) / 60 * Self.hourHeight
    }

    private func height(of item: ScheduleItem) -> CGFloat {
        CGFloat(item.end.timeIntervalSince(item.start) / 3600) * Self.hourHeight - 2
    }

    private func nowOffset(in range: ClosedRange<Int>) -> CGFloat? {
        guard day == .today() else { return nil }
        let offset = self.offset(of: now, in: range)
        let limit = CGFloat(range.upperBound - range.lowerBound) * Self.hourHeight
        return (offset >= 0 && offset <= limit) ? offset : nil
    }

    // MARK: Actions

    private func open(_ item: ScheduleItem) {
        switch item.kind {
        case .block(let id):
            if let block = model.timeBlocks.first(where: { $0.id == id }) { sheet = .edit(block) }
        case .event:
            if let event = model.events(on: day).first(where: { $0.id == item.id }) { model.openInCalendar(event) }
        case .task:
            break
        }
    }

    private func blockTime(for ref: TaskRef, at hour: Int) {
        guard let start = date(hour: hour) else { return }
        let notes = "From [[\(ref.noteTitle)]]\nams-para:timeblock"
        Task {
            await model.saveTimeBlock(id: nil, title: ref.task.title, start: start,
                                      end: start.addingTimeInterval(3600), notes: notes, calendarID: nil)
        }
    }

    private func date(hour: Int) -> Date? {
        guard let base = day.date(calendar: calendar) else { return nil }
        return calendar.date(bySettingHour: min(23, hour), minute: 0, second: 0, of: base)
    }

    private func defaultStart() -> Date? {
        day == .today() ? date(hour: calendar.component(.hour, from: Date()) + 1) : date(hour: 9)
    }

    // MARK: Text

    private func hourText(_ hour: Int) -> String {
        guard let date = date(hour: hour) else { return "\(hour)" }
        return Self.hourLabel.string(from: date)
    }

    private func timeText(_ start: Date, _ end: Date) -> String {
        "\(Self.timeLabel.string(from: start))–\(Self.timeLabel.string(from: end))"
    }
}

/// An item with the lane it was given, so overlapping things sit side by side.
struct PlacedItem: Identifiable {
    var item: ScheduleItem
    var lane: Int
    var lanes: Int

    var id: String { item.id }
}

/// One block drawn on the timeline.
struct ScheduleItemView: View {
    let item: ScheduleItem

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption.weight(item.isBlock ? .semibold : .regular))
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(item.color.opacity(item.isBlock ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(item.color.opacity(item.isBlock ? 0.55 : 0.25), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .help(item.title + " · " + item.subtitle)
    }
}

/// Create or change one time block, from the schedule.
struct TimeBlockSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let block: TimeBlock?
    let day: DateOnly
    let start: Date?
    let done: () -> Void

    @State private var title = ""
    @State private var startDate = Date()
    @State private var minutes = 60
    @State private var notes = ""
    @State private var calendarID: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(block == nil ? "New time block" : "Time block")
                .font(.headline)
            Form {
                TextField("Title", text: $title)
                DatePicker("Starts", selection: $startDate)
                Picker("Length", selection: $minutes) {
                    ForEach([15, 30, 45, 60, 90, 120, 180, 240], id: \.self) { value in
                        Text(lengthLabel(value)).tag(value)
                    }
                }
                Picker("Calendar", selection: $calendarID) {
                    Text("Default").tag(String?.none)
                    ForEach(model.calendars.filter(\.isWritable)) { calendar in
                        Text(calendar.title).tag(String?.some(calendar.id))
                    }
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)
            HStack {
                if let block {
                    Button("Delete", role: .destructive) {
                        Task {
                            await model.deleteTimeBlock(block)
                            finish()
                        }
                    }
                }
                Spacer()
                Button("Cancel") { finish() }
                Button(block == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
            }
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 380)
        .onAppear(perform: load)
    }

    private func lengthLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    private func load() {
        if let block {
            title = block.title
            startDate = block.start
            minutes = max(5, Int(block.end.timeIntervalSince(block.start) / 60))
            notes = block.notes
            calendarID = block.calendarID
        } else {
            startDate = start ?? day.date() ?? Date()
            notes = "ams-para:timeblock"
        }
    }

    private func save() {
        saving = true
        let end = startDate.addingTimeInterval(TimeInterval(minutes * 60))
        Task {
            await model.saveTimeBlock(id: block?.id, title: title, start: startDate, end: end,
                                      notes: notes, calendarID: calendarID)
            finish()
        }
    }

    private func finish() {
        saving = false
        done()
        dismiss()
    }
}

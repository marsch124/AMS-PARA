import SwiftUI
import AMSParaCore

/// The Time Blocks section: blocks of time that live in Apple Calendar, separate from tasks.
/// A form at the top adds or edits a block; the list below shows the coming weeks.
struct TimeBlocksView: View {
    @EnvironmentObject private var model: AppModel

    @State private var editingID: String?
    @State private var title = ""
    @State private var day = Date()
    @State private var start = TimeBlocksView.roundedNow()
    @State private var durationMinutes = 60
    @State private var notes = ""
    @State private var calendarID: String?
    @State private var blockToDelete: TimeBlock?
    @FocusState private var titleFocused: Bool

    private static let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            list
        }
        .task { await model.loadTimeBlocks() }
        .onAppear {
            if calendarID == nil { calendarID = model.timeBlockCalendarID }
            consumeDraft()
        }
        .onChange(of: model.timeBlockDraft) { _, _ in consumeDraft() }
        .confirmationDialog("Delete \u{201C}\(blockToDelete?.title ?? "")\u{201D} from Apple Calendar?",
                            isPresented: Binding(get: { blockToDelete != nil }, set: { if !$0 { blockToDelete = nil } }),
                            presenting: blockToDelete) { block in
            Button("Delete", role: .destructive) {
                Task { await model.deleteTimeBlock(block) }
                if editingID == block.id { reset() }
            }
        } message: { _ in
            Text("The event is removed from the calendar on all your devices.")
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(editingID == nil ? "New time block" : "Edit time block")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if editingID != nil {
                    Button("Cancel", action: reset)
                }
            }
            TextField("What is this time for?", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit(save)
            HStack(spacing: 10) {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                    .labelsHidden()
                DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Picker("For", selection: $durationMinutes) {
                    ForEach(Self.durations, id: \.self) { minutes in
                        Text(Self.durationLabel(minutes)).tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 110)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Picker("Calendar", selection: $calendarID) {
                    ForEach(model.calendars.filter(\.isWritable)) { calendar in
                        Label {
                            Text(calendar.title)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(calendar.color)
                        }
                        .tag(Optional(calendar.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer(minLength: 0)
                Button(editingID == nil ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            if model.calendarAccessGranted == false {
                Text("Calendar access is off. Allow it in System Settings › Privacy & Security › Calendars.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
    }

    // MARK: List

    private var list: some View {
        let grouped = Dictionary(grouping: model.timeBlocks, by: \.day)
        let days = grouped.keys.sorted()
        return List {
            if days.isEmpty {
                Text(model.calendarAccessGranted == false
                     ? "Time blocks need Calendar access."
                     : "No time blocks yet. Add one above; it becomes an event in Apple Calendar.")
                    .foregroundStyle(.secondary)
            }
            ForEach(days, id: \.self) { day in
                Section(Self.dayLabel(day)) {
                    ForEach(grouped[day] ?? []) { block in
                        row(block)
                    }
                }
            }
        }
    }

    private func row(_ block: TimeBlock) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(block.color)
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
            Text("\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(block.title)
                    .fontWeight(editingID == block.id ? .semibold : .regular)
                    .lineLimit(1)
                if !block.notes.isEmpty {
                    Text(block.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(block.calendarTitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { edit(block) }
        .contextMenu {
            Button("Edit") { edit(block) }
            Button("Open in Calendar") { model.openInCalendar(block) }
            Divider()
            Button("Delete…", role: .destructive) { blockToDelete = block }
        }
        .help("Click to edit. Right-click to open in Calendar or delete.")
    }

    // MARK: Actions

    /// "Block time for this…" on a task lands here.
    private func consumeDraft() {
        guard let draft = model.timeBlockDraft else { return }
        editingID = nil
        title = draft.title
        notes = draft.notes
        day = Date()
        start = Self.roundedNow()
        titleFocused = true
        model.afterUpdate { model.timeBlockDraft = nil }
    }

    private func edit(_ block: TimeBlock) {
        editingID = block.id
        title = block.title
        day = block.start
        start = block.start
        durationMinutes = max(15, Int(block.end.timeIntervalSince(block.start) / 60))
        notes = block.notes
        calendarID = block.calendarID
        titleFocused = true
    }

    private func reset() {
        editingID = nil
        title = ""
        notes = ""
        start = Self.roundedNow()
        durationMinutes = 60
    }

    private func save() {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: start)
        guard let begin = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: day) else { return }
        let finish = begin.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let id = editingID
        Task {
            if await model.saveTimeBlock(id: id, title: title, start: begin, end: finish, notes: notes, calendarID: calendarID) {
                reset()
                titleFocused = true
            }
        }
    }

    // MARK: Helpers

    /// The next quarter hour from now, so a new block starts at a sensible time.
    private static func roundedNow() -> Date {
        let now = Date()
        let minute = Calendar.current.component(.minute, from: now)
        let add = (15 - minute % 15) % 15
        return Calendar.current.date(byAdding: .minute, value: add, to: now).map {
            Calendar.current.date(bySetting: .second, value: 0, of: $0) ?? $0
        } ?? now
    }

    private static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 { return "\(minutes / 60) h" }
        return "\(minutes / 60) h \(minutes % 60)"
    }

    private static func dayLabel(_ day: DateOnly) -> String {
        let today = DateOnly.today()
        if day == today { return "Today" }
        if day == today.adding(days: 1) { return "Tomorrow" }
        if day == today.adding(days: -1) { return "Yesterday" }
        guard let date = day.date() else { return day.description }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

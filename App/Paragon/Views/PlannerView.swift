import SwiftUI
import ParagonCore

/// Plan the day: the calendar on the left, your own blocks in the middle, the day's actions on
/// the right.
///
/// He drew this and chose its shape from a preview artifact
/// (https://claude.ai/code/artifact/82be810e-11ca-4c7b-8fc2-3863ff07cfbd). The one decision that
/// matters is what a block *is*: not a calendar event and not a task, but a line in the daily
/// note under `## Plan` saying where he means to be. The Time Blocks section of build 35 is the
/// other thing — real events in Apple Calendar — and the two are kept apart on purpose.
///
/// Calendar and blocks hang on the same hours, which is the whole reason for choosing this
/// shape over three loose columns: a block at 09:30 has to show that it lands inside a round of
/// golf that runs to 12:20.
struct PlannerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var day: DateOnly = .today()
    @State private var editing: PlanBlock?
    @State private var draftTitle = ""
    @State private var draftStart = 9 * 60
    @State private var draftMinutes = 60
    @State private var showingEditor = false

    /// The hours drawn. Six in the morning to eleven at night covers a day without making the
    /// column a mile long; anything outside it is still listed, above the ruler.
    private let firstHour = 6
    private let lastHour = 23
    private let hourHeight: CGFloat = 44

    private var blocks: [PlanBlock] { model.planBlocks(for: day) }
    private var actions: [TaskRef] { model.actionsForPlanning(on: day) }
    private var laneHeight: CGFloat { CGFloat(lastHour - firstHour + 1) * hourHeight }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        hours
                        lane(title: "Calendar", tint: SidebarSection.calendar.tint) { calendarItems }
                        Divider()
                        lane(title: "Time blocks", tint: SidebarSection.review.tint) { blockItems }
                    }
                }
                Divider()
                actionList
                    .frame(width: 260)
            }
        }
        .navigationTitle("Plan the day")
        .modifier(CalendarBlocksLink())
        .task(id: day) { await model.loadEvents(for: day) }
        // One sheet on this screen, for both a new block and an existing one (build 44).
        .sheet(isPresented: $showingEditor) { editorSheet }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .help("The day before")
                Button("Today") { day = .today() }
                    .disabled(day == .today())
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .help("The day after")
            }
            .buttonStyle(.borderless)
            .fixedSize()
            Button {
                startNewBlock(at: 9 * 60)
            } label: {
                Label("Block", systemImage: "plus")
            }
            .fixedSize()
            .help("Add a block to this day's plan")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var dayTitle: String {
        guard let date = day.date() else { return day.description }
        return PlannerView.longDate.string(from: date)
    }

    /// Plain text, built outside the ViewBuilder.
    private var summary: String {
        var parts: [String] = []
        parts.append(blocks.isEmpty ? "no blocks yet" : (blocks.count == 1 ? "1 block" : "\(blocks.count) blocks"))
        let events = model.events(on: day).filter { !$0.isAllDay }.count
        if events > 0 { parts.append(events == 1 ? "1 event" : "\(events) events") }
        if !actions.isEmpty { parts.append("\(actions.count) to choose from") }
        return parts.joined(separator: " \u{00b7} ")
    }

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM y")
        return f
    }()

    private func move(_ days: Int) {
        day = day.adding(days: days, calendar: WeekRef.calendar)
    }

    // MARK: The two lanes

    private var hours: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(firstHour...lastHour, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(height: hourHeight, alignment: .top)
                    .padding(.trailing, 6)
            }
        }
        .frame(width: 34)
        .padding(.top, 26)
    }

    /// A titled column with hour rules behind it. `content` is placed with `.offset` inside a
    /// top-leading stack, never `.position`: a positioned view claims its parent's whole size
    /// and swallows every click in it (build 85).
    private func lane<Content: View>(title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: title, count: nil, tint: tint)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .frame(height: 26, alignment: .bottom)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(firstHour...lastHour, id: \.self) { _ in
                        Divider()
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: laneHeight)
                content()
            }
            .frame(height: laneHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var calendarItems: some View {
        ForEach(placedEvents) { placed in
            card(title: placed.title, time: placed.time, tint: SidebarSection.calendar.tint, filled: false)
                .frame(height: placed.height)
                .offset(x: 4, y: placed.top)
                .padding(.trailing, 8)
        }
    }

    @ViewBuilder
    private var blockItems: some View {
        ForEach(blocks) { block in
            Button {
                startEditing(block)
            } label: {
                card(title: block.title, time: block.timeText, tint: SidebarSection.review.tint, filled: true)
                    .frame(height: height(forMinutes: block.minutes))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: top(forMinutes: block.start))
            .padding(.trailing, 8)
            .contextMenu {
                Button("Edit\u{2026}") { startEditing(block) }
                Button("Remove", role: .destructive) { model.removePlanBlock(block, on: day) }
            }
        }
    }

    private func card(title: String, time: String, tint: Color, filled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(tint.opacity(0.85))
            Text(title)
                .font(.caption.weight(filled ? .semibold : .regular))
                .foregroundStyle(tint)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(filled ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(tint.opacity(filled ? 0.5 : 0.28), lineWidth: 1)
        )
    }

    // MARK: Where things sit

    private func top(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes - firstHour * 60) / 60 * hourHeight
    }

    private func height(forMinutes minutes: Int) -> CGFloat {
        max(22, CGFloat(minutes) / 60 * hourHeight)
    }

    /// A calendar event worked out in lane coordinates. A struct rather than a tuple, because
    /// a key path cannot address a tuple member (build 61).
    private struct PlacedEvent: Identifiable {
        let id: String
        let title: String
        let time: String
        let top: CGFloat
        let height: CGFloat
    }

    private var placedEvents: [PlacedEvent] {
        let calendar = WeekRef.calendar
        return model.events(on: day).compactMap { event in
            guard !event.isAllDay else { return nil }
            let startParts = calendar.dateComponents([.hour, .minute], from: event.start)
            let endParts = calendar.dateComponents([.hour, .minute], from: event.end)
            let start = (startParts.hour ?? 0) * 60 + (startParts.minute ?? 0)
            var end = (endParts.hour ?? 0) * 60 + (endParts.minute ?? 0)
            if end <= start { end = start + 30 }
            return PlacedEvent(id: event.id,
                               title: event.title,
                               time: "\(PlanBlock.clock(start)) \u{2013} \(PlanBlock.clock(end))",
                               top: top(forMinutes: start),
                               height: height(forMinutes: end - start))
        }
    }

    // MARK: The actions column

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Actions", count: actions.isEmpty ? nil : actions.count,
                         tint: SidebarSection.allActions.tint)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .frame(height: 26, alignment: .bottom)
            Divider()
            if actions.isEmpty {
                Text("Nothing due today and no next actions. Give a task a date, or mark one as the next action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(actions) { ref in
                        Button {
                            startNewBlock(at: nextFreeStart(), titled: ref.task.title)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ref.task.title)
                                    .font(.caption)
                                    .lineLimit(3)
                                Text(ref.noteTitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Make a block for this")
                    }
                }
            }
        }
    }

    // MARK: Making and changing a block

    /// The first half hour after the last block, so a new one lands somewhere sensible.
    private func nextFreeStart() -> Int {
        guard let last = blocks.map(\.end).max() else { return 9 * 60 }
        return min(last, 23 * 60)
    }

    private func startNewBlock(at start: Int, titled title: String = "") {
        editing = nil
        draftTitle = title
        draftStart = start
        draftMinutes = 60
        showingEditor = true
    }

    private func startEditing(_ block: PlanBlock) {
        editing = block
        draftTitle = block.title
        draftStart = block.start
        draftMinutes = block.minutes
        showingEditor = true
    }

    private var editorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editing == nil ? "New block" : "Edit block")
                .font(.headline)
            TextField("What is this time for?", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 10) {
                Picker("Starts", selection: $draftStart) {
                    ForEach(startChoices, id: \.self) { minutes in
                        Text(PlanBlock.clock(minutes)).tag(minutes)
                    }
                }
                Picker("For", selection: $draftMinutes) {
                    ForEach(PlannerView.durations, id: \.self) { minutes in
                        Text(PlannerView.durationLabel(minutes)).tag(minutes)
                    }
                }
            }
            Text("A block is only for you. It is never written to Apple Calendar and never becomes a task \u{2014} it is a line in this day's note under Plan.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let editing {
                    Button("Remove", role: .destructive) {
                        model.removePlanBlock(editing, on: day)
                        showingEditor = false
                    }
                }
                Spacer()
                Button("Cancel") { showingEditor = false }
                Button("Save", action: saveDraft)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(minWidth: 360)
    }

    private var startChoices: [Int] {
        stride(from: firstHour * 60, through: lastHour * 60 + 30, by: 15).map { $0 }
    }

    private static let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    private static func durationLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min"
            : (minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min")
    }

    private func saveDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let made = PlanBlock(start: draftStart, end: draftStart + draftMinutes, title: title,
                             index: editing?.index ?? 0)
        if editing != nil {
            model.replacePlanBlock(made, on: day)
        } else {
            model.addPlanBlock(made, on: day)
        }
        showingEditor = false
    }
}

/// The phone's one way to the old blocks, the ones that are events in Apple Calendar.
///
/// A modifier rather than an `#if` in the middle of the chain: conditional compilation inside
/// a modifier chain is the shape that broke the scene list in build 147, and here it would
/// also have to hold `ToolbarItem(placement: .topBarTrailing)`, which macOS does not have.
/// One control beside the back button and the title, and no more — three is what made
/// build 88 draw overlapping letters.
private struct CalendarBlocksLink: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: PhoneRoute.calendarBlocks) {
                    Image(systemName: "calendar.badge.clock")
                }
                .accessibilityLabel("Blocks in Apple Calendar")
            }
        }
        #else
        content
        #endif
    }
}
